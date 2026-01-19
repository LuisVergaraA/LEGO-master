#include "common.h"
#include <semaphore.h>

// Variables globales
BandaTransportadora *banda = NULL;
EstadisticasGlobales *stats = NULL;
int shmid_banda = -1, shmid_stats = -1;
int semid_banda = -1, semid_stats = -1;

// Estructura de la celda
typedef struct {
    int id_celda;
    int posicion_banda;
    ConfiguracionSET set_config;
    EstadoCaja caja_actual;
    EstadoBrazo brazos[BRAZOS_POR_CELDA];
    int celda_activa;
    
    // Sincronización
    pthread_mutex_t mutex_caja;
    sem_t sem_retirar;  // Máximo 2 retiran
    pthread_mutex_t mutex_captura;  // NUEVO: proteger buscar+retirar
    pthread_mutex_t mutex_brazos;
    
    // Balance - CORREGIDO según PDF
    pthread_mutex_t mutex_balance;
    int ultimo_checkpoint;
    
    // Estadísticas
    int cajas_completadas;
    int cajas_fallidas;
    int total_piezas_procesadas;
    time_t tiempo_inicio;
} Celda;

Celda celda;

typedef struct {
    int id_brazo;
    Celda* celda;
} BrazoArgs;

void cleanup_handler(int sig) {
    (void)sig;
    signal(SIGINT, SIG_IGN);
    signal(SIGTERM, SIG_IGN);
    
    printf("\n");
    print_timestamp("Deteniendo celda...\n");
    celda.celda_activa = 0;
    sleep(1);
    
    // Desregistrar celda
    if (banda != NULL) {
        sem_wait_op(semid_banda, 0);
        for (int i = 0; i < banda->num_celdas; i++) {
            if (banda->pos_celdas[i] == celda.posicion_banda) {
                for (int j = i; j < banda->num_celdas - 1; j++) {
                    banda->pos_celdas[j] = banda->pos_celdas[j + 1];
                }
                banda->pos_celdas[banda->num_celdas - 1] = -1;
                banda->num_celdas--;
                printf("[CELDA %d] Desregistrada de la banda\n", celda.id_celda);
                break;
            }
        }
        sem_signal_op(semid_banda, 0);
        shmdt(banda);
    }
    
    if (stats != NULL) shmdt(stats);
    print_timestamp("Celda finalizada.\n");
    exit(0);
}

int conectar_memoria_compartida() {
    // Conectar a banda (obligatorio)
    shmid_banda = shmget(KEY_BANDA, sizeof(BandaTransportadora), 0666);
    if (shmid_banda < 0) {
        perror("shmget banda");
        return -1;
    }
    
    banda = (BandaTransportadora *)shmat(shmid_banda, NULL, 0);
    if (banda == (BandaTransportadora *)-1) {
        perror("shmat banda");
        return -1;
    }
    
    semid_banda = semget(KEY_SEM_BANDA, 0, 0666);
    if (semid_banda < 0) {
        perror("semget banda");
        return -1;
    }
    
    // Conectar a estadísticas
    shmid_stats = shmget(KEY_STATS, sizeof(EstadisticasGlobales), IPC_CREAT | 0666);
    if (shmid_stats >= 0) {
        stats = (EstadisticasGlobales *)shmat(shmid_stats, NULL, 0);
        if (stats == (EstadisticasGlobales *)-1) {
            stats = NULL;
        } else {
            semid_stats = semget(KEY_SEM_STATS, 1, IPC_CREAT | 0666);
            if (semid_stats >= 0) {
                sem_init_value(semid_stats, 0, 1);
            } else {
                stats = NULL;
                semid_stats = -1;
            }
        }
    }
    
    return 0;
}

int registrar_celda() {
    sem_wait_op(semid_banda, 0);
    
    if (banda->num_celdas >= MAX_CELDAS) {
        sem_signal_op(semid_banda, 0);
        return -1;
    }
    
    banda->pos_celdas[banda->num_celdas] = celda.posicion_banda;
    banda->num_celdas++;
    sem_signal_op(semid_banda, 0);
    
    return 0;
}

// CORREGIDO: Captura atómica de pieza (buscar + retirar en una operación)
int capturar_pieza_atomica(int posicion, int* tipo_capturado) {
    if (posicion < 0 || posicion >= banda->tamanio) return -1;
    
    *tipo_capturado = VACIO;
    
    // Bloquear TODA la operación de captura
    pthread_mutex_lock(&celda.mutex_captura);
    
    // Bloquear acceso a la banda
    sem_wait_op(semid_banda, 0);
    
    PosicionBanda* pos = &banda->posiciones[posicion];
    int resultado = -1;
    
    // Buscar pieza que necesitemos
    for (int i = 0; i < pos->count; i++) {
        int tipo = pos->piezas[i];
        if (tipo == VACIO) continue;
        
        int indice = tipo_a_indice(tipo);
        if (indice < 0) continue;
        
        // Verificar si necesitamos esta pieza (protegiendo lectura de caja)
        pthread_mutex_lock(&celda.mutex_caja);
        int necesitamos = (celda.caja_actual.piezas_actuales[indice] < 
                          celda.set_config.piezas_requeridas[indice]);
        pthread_mutex_unlock(&celda.mutex_caja);
        
        if (necesitamos) {
            // REMOVER INMEDIATAMENTE de la banda
            if (remover_pieza_de_posicion(pos, tipo) == 0) {
                *tipo_capturado = tipo;
                resultado = 0;
                break;  // Salir del loop - ya capturamos una pieza
            }
        }
    }
    
    sem_signal_op(semid_banda, 0);
    pthread_mutex_unlock(&celda.mutex_captura);
    
    return resultado;
}

void depositar_en_caja(int tipo) {
    int indice = tipo_a_indice(tipo);
    if (indice < 0) return;
    
    celda.caja_actual.piezas_actuales[indice]++;
    celda.total_piezas_procesadas++;
}

int caja_completa() {
    for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
        if (celda.caja_actual.piezas_actuales[i] < celda.set_config.piezas_requeridas[i]) {
            return 0;
        }
    }
    return 1;
}

// CORREGIDO: Balance según PDF - basado en piezas DISPENSADAS globalmente
int verificar_y_aplicar_balance(int mi_id) {
    if (stats == NULL || semid_stats < 0) return 0;
    
    pthread_mutex_lock(&celda.mutex_balance);
    
    // Leer contador GLOBAL de piezas dispensadas
    sem_wait_op(semid_stats, 0);
    int total_dispensadas = stats->total_piezas_dispensadas;
    sem_signal_op(semid_stats, 0);
    
    int checkpoint = celda.ultimo_checkpoint;
    
    // "Cada Y piezas dispensadas" - verificar si alcanzamos múltiplo de Y
    if (total_dispensadas >= checkpoint + Y_TIPOS_PIEZAS) {
        celda.ultimo_checkpoint = checkpoint + Y_TIPOS_PIEZAS;
        pthread_mutex_unlock(&celda.mutex_balance);
        
        // Determinar brazo con MÁS piezas procesadas
        pthread_mutex_lock(&celda.mutex_brazos);
        int max_piezas = -1;
        int brazo_max = -1;
        
        for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
            if (celda.brazos[i].piezas_procesadas > max_piezas) {
                max_piezas = celda.brazos[i].piezas_procesadas;
                brazo_max = i;
            }
        }
        pthread_mutex_unlock(&celda.mutex_brazos);
        
        // Si YO soy el brazo más ocupado, suspenderme
        if (brazo_max == mi_id && max_piezas > 0) {
            printf("[BRAZO %d] 💤 Suspendido por balance (%d piezas procesadas, checkpoint: %d)\n", 
                   mi_id, max_piezas, total_dispensadas);
            
            pthread_mutex_lock(&celda.mutex_brazos);
            celda.brazos[mi_id].suspendido = 1;
            pthread_mutex_unlock(&celda.mutex_brazos);
            
            usleep(DELTA_T2);
            
            pthread_mutex_lock(&celda.mutex_brazos);
            celda.brazos[mi_id].suspendido = 0;
            pthread_mutex_unlock(&celda.mutex_brazos);
            
            printf("[BRAZO %d] ✅ Reactivado después de suspensión\n", mi_id);
            return 1;
        }
    } else {
        pthread_mutex_unlock(&celda.mutex_balance);
    }
    
    return 0;
}

void validar_caja() {
    printf("[CELDA %d] 📦 Caja completa, notificando operador...\n", celda.id_celda);
    
    // Simular tiempo de operador humano (0 a MAX_DELTA_T1)
    int tiempo_operador = rand() % (MAX_DELTA_T1 + 1);
    usleep(tiempo_operador);
    
    // Verificar corrección
    int correcta = 1;
    for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
        if (celda.caja_actual.piezas_actuales[i] != celda.set_config.piezas_requeridas[i]) {
            correcta = 0;
            break;
        }
    }
    
    if (correcta) {
        printf("[OPERADOR] ✅ OK - Caja #%d correcta (Celda %d)\n", 
               celda.cajas_completadas + 1, celda.id_celda);
        celda.cajas_completadas++;
        
        if (stats != NULL && semid_stats >= 0) {
            sem_wait_op(semid_stats, 0);
            stats->cajas_ok++;
            sem_signal_op(semid_stats, 0);
        }
    } else {
        printf("[OPERADOR] ❌ FAIL - Caja con errores (Celda %d)\n", celda.id_celda);
        printf("  Esperado: A=%d B=%d C=%d D=%d\n",
               celda.set_config.piezas_requeridas[0],
               celda.set_config.piezas_requeridas[1],
               celda.set_config.piezas_requeridas[2],
               celda.set_config.piezas_requeridas[3]);
        printf("  Obtenido: A=%d B=%d C=%d D=%d\n",
               celda.caja_actual.piezas_actuales[0],
               celda.caja_actual.piezas_actuales[1],
               celda.caja_actual.piezas_actuales[2],
               celda.caja_actual.piezas_actuales[3]);
        celda.cajas_fallidas++;
        
        if (stats != NULL && semid_stats >= 0) {
            sem_wait_op(semid_stats, 0);
            stats->cajas_fail++;
            sem_signal_op(semid_stats, 0);
        }
    }
    
    // Reiniciar caja
    memset(&celda.caja_actual, 0, sizeof(EstadoCaja));
    
    printf("[CELDA %d] 🔄 Nueva caja iniciada\n", celda.id_celda);
    
    // Pausa breve entre cajas para redistribución
    usleep(500000); // 500ms
}

void* brazo_worker(void* arg) {
    BrazoArgs* args = (BrazoArgs*)arg;
    int mi_id = args->id_brazo;
    
    printf("[BRAZO %d] Iniciado (Celda %d)\n", mi_id, celda.id_celda);
    
    while (celda.celda_activa && banda->activa > 0) {
        int tipo_pieza = VACIO;
        
        // 1. Esperar permiso para retirar (máximo 2 simultáneos)
        sem_wait(&celda.sem_retirar);
        
        // 2. Captura ATÓMICA: buscar + retirar en una operación protegida
        if (capturar_pieza_atomica(celda.posicion_banda, &tipo_pieza) == 0 && tipo_pieza != VACIO) {
            // Pieza capturada exitosamente
            usleep(TIEMPO_AGARRE);
            sem_post(&celda.sem_retirar);
            
            // 3. Depositar en caja (solo 1 a la vez)
            pthread_mutex_lock(&celda.mutex_caja);
            
            int indice = tipo_a_indice(tipo_pieza);
            
            // Verificar que aún necesitamos esta pieza
            if (indice >= 0 && 
                celda.caja_actual.piezas_actuales[indice] < celda.set_config.piezas_requeridas[indice]) {
                
                depositar_en_caja(tipo_pieza);
                
                // Actualizar contador del brazo
                pthread_mutex_lock(&celda.mutex_brazos);
                celda.brazos[mi_id].piezas_procesadas++;
                pthread_mutex_unlock(&celda.mutex_brazos);
                
                usleep(TIEMPO_DEPOSITO);
                
                // 4. Verificar si caja completa
                if (caja_completa()) {
                    validar_caja();
                }
            }
            
            pthread_mutex_unlock(&celda.mutex_caja);
            
            // 5. Verificar balance después de depositar
            verificar_y_aplicar_balance(mi_id);
            
        } else {
            // No había pieza disponible
            sem_post(&celda.sem_retirar);
            usleep(50000); // Esperar un poco antes de reintentar
        }
    }
    
    printf("[BRAZO %d] Finalizado - Procesó %d piezas\n", 
           mi_id, celda.brazos[mi_id].piezas_procesadas);
    
    return NULL;
}

void inicializar_celda(int id, int posicion, int pzA, int pzB, int pzC, int pzD) {
    celda.id_celda = id;
    celda.posicion_banda = posicion;
    celda.celda_activa = 1;
    celda.cajas_completadas = 0;
    celda.cajas_fallidas = 0;
    celda.total_piezas_procesadas = 0;
    celda.tiempo_inicio = time(NULL);
    
    celda.set_config.piezas_requeridas[0] = pzA;
    celda.set_config.piezas_requeridas[1] = pzB;
    celda.set_config.piezas_requeridas[2] = pzC;
    celda.set_config.piezas_requeridas[3] = pzD;
    celda.set_config.total_piezas = pzA + pzB + pzC + pzD;
    
    memset(&celda.caja_actual, 0, sizeof(EstadoCaja));
    
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        celda.brazos[i].id_brazo = i;
        celda.brazos[i].piezas_procesadas = 0;
        celda.brazos[i].suspendido = 0;
    }
    
    pthread_mutex_init(&celda.mutex_caja, NULL);
    pthread_mutex_init(&celda.mutex_brazos, NULL);
    pthread_mutex_init(&celda.mutex_balance, NULL);
    pthread_mutex_init(&celda.mutex_captura, NULL); // NUEVO
    sem_init(&celda.sem_retirar, 0, 2);
    
    celda.ultimo_checkpoint = 0;
}

void mostrar_resumen_final() {
    time_t ahora = time(NULL);
    int duracion = (int)difftime(ahora, celda.tiempo_inicio);
    
    printf("\n");
    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║       RESUMEN FINAL - CELDA %d (Posición %d)              ║\n", 
           celda.id_celda, celda.posicion_banda);
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("\n");
    
    printf("⏱️  TIEMPO DE OPERACIÓN: %d segundos (%.1f minutos)\n\n",
           duracion, duracion / 60.0);
    
    printf("📦 PRODUCCIÓN:\n");
    printf("   Cajas completadas OK: %d\n", celda.cajas_completadas);
    printf("   Cajas con errores: %d\n", celda.cajas_fallidas);
    printf("   Total piezas procesadas: %d\n", celda.total_piezas_procesadas);
    
    if (celda.cajas_completadas + celda.cajas_fallidas > 0) {
        float tasa = (float)celda.cajas_completadas / 
                     (celda.cajas_completadas + celda.cajas_fallidas) * 100;
        printf("   Tasa de éxito: %.1f%%\n", tasa);
    }
    printf("\n");
    
    printf("🤖 ESTADÍSTICAS POR BRAZO:\n");
    int total = 0, min_p = 999999, max_p = 0;
    
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        int p = celda.brazos[i].piezas_procesadas;
        printf("   Brazo %d: %d piezas", i, p);
        total += p;
        if (p < min_p) min_p = p;
        if (p > max_p) max_p = p;
        
        if (celda.total_piezas_procesadas > 0) {
            printf(" (%.1f%%)", (float)p / celda.total_piezas_procesadas * 100);
        }
        printf("\n");
    }
    
    printf("\n⚖️  BALANCE DE CARGA:\n");
    if (BRAZOS_POR_CELDA > 0 && total > 0) {
        float prom = (float)total / BRAZOS_POR_CELDA;
        float desb = max_p - min_p;
        float desb_pct = (desb / prom) * 100;
        
        printf("   Promedio: %.1f | Min: %d | Max: %d | Diff: %.0f\n",
               prom, min_p, max_p, desb);
        printf("   Desbalance: %.1f%%", desb_pct);
        
        if (desb_pct < 10) printf(" ✅ Excelente\n");
        else if (desb_pct < 25) printf(" ✓ Bueno\n");
        else if (desb_pct < 50) printf(" ⚠ Regular\n");
        else printf(" ❌ Malo\n");
    }
    
    printf("\n╚═══════════════════════════════════════════════════════════╝\n");
}

void ejecutar_celda() {
    pthread_t threads[BRAZOS_POR_CELDA];
    BrazoArgs args[BRAZOS_POR_CELDA];
    
    print_timestamp("Celda iniciada\n");
    printf("ID: %d | Posición: %d | SET: A=%d B=%d C=%d D=%d\n",
           celda.id_celda, celda.posicion_banda,
           celda.set_config.piezas_requeridas[0],
           celda.set_config.piezas_requeridas[1],
           celda.set_config.piezas_requeridas[2],
           celda.set_config.piezas_requeridas[3]);
    printf("Restricciones: Máx 2 brazos retiran | 1 deposita | Balance cada %d piezas dispensadas\n\n",
           Y_TIPOS_PIEZAS);
    
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        args[i].id_brazo = i;
        args[i].celda = &celda;
        
        if (pthread_create(&threads[i], NULL, brazo_worker, &args[i]) != 0) {
            perror("pthread_create");
            celda.celda_activa = 0;
            return;
        }
    }
    
    printf("[CELDA %d] 🤖 Brazos activos. Esperando piezas...\n\n", celda.id_celda);
    
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        pthread_join(threads[i], NULL);
    }
    
    mostrar_resumen_final();
}

int main(int argc, char *argv[]) {
    if (argc != 7) {
        fprintf(stderr, "Uso: %s <id_celda> <posicion> <pzA> <pzB> <pzC> <pzD>\n", argv[0]);
        fprintf(stderr, "Ejemplo: %s 1 20 3 2 4 1\n", argv[0]);
        exit(EXIT_FAILURE);
    }
    
    int id = atoi(argv[1]);
    int posicion = atoi(argv[2]);
    int pzA = atoi(argv[3]);
    int pzB = atoi(argv[4]);
    int pzC = atoi(argv[5]);
    int pzD = atoi(argv[6]);
    
    if (id < 1 || id > MAX_CELDAS || posicion < 0 || posicion >= MAX_BANDA) {
        fprintf(stderr, "Error: Parámetros inválidos\n");
        exit(EXIT_FAILURE);
    }
    
    signal(SIGINT, cleanup_handler);
    signal(SIGTERM, cleanup_handler);
    signal(SIGHUP, cleanup_handler);
    
    srand(time(NULL) + id);
    
    if (conectar_memoria_compartida() < 0) {
        fprintf(stderr, "Error: Sistema no disponible\n");
        exit(EXIT_FAILURE);
    }
    
    inicializar_celda(id, posicion, pzA, pzB, pzC, pzD);
    
    if (registrar_celda() < 0) {
        fprintf(stderr, "Error: No se pudo registrar celda\n");
        exit(EXIT_FAILURE);
    }
    
    print_timestamp("Celda registrada exitosamente\n");
    ejecutar_celda();
    
    pthread_mutex_destroy(&celda.mutex_caja);
    pthread_mutex_destroy(&celda.mutex_brazos);
    pthread_mutex_destroy(&celda.mutex_balance);
    pthread_mutex_destroy(&celda.mutex_captura);
    sem_destroy(&celda.sem_retirar);
    
    if (banda != NULL) shmdt(banda);
    if (stats != NULL) shmdt(stats);
    
    return 0;
}