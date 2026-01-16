#include "common.h"
#include <semaphore.h>

// Variables globales
BandaTransportadora *banda = NULL;
EstadisticasGlobales *stats = NULL;
int shmid_banda = -1;
int shmid_stats = -1;
int semid_banda = -1;
int semid_stats = -1;

// Estructura de la celda
typedef struct {
    int id_celda;
    int posicion_banda;
    ConfiguracionSET set_config;
    EstadoCaja caja_actual;
    EstadoBrazo brazos[BRAZOS_POR_CELDA];
    int celda_activa;
    
    // Sincronización
    pthread_mutex_t mutex_caja;       // Solo 1 deposita
    sem_t sem_retirar;                // Solo 2 retiran (valor = 2)
    pthread_mutex_t mutex_brazos;     // Proteger array de brazos
    
    // Balance de brazos (Día 4)
    int piezas_totales_procesadas;   // Contador global para balance
    int ultimo_checkpoint;            // Último checkpoint de balance
    pthread_mutex_t mutex_balance;    // Proteger variables de balance
    
    // Estadísticas
    int cajas_completadas;
    int cajas_fallidas;
    int total_piezas_procesadas;
} Celda;

Celda celda;

// Argumentos para threads de brazos
typedef struct {
    int id_brazo;
    Celda* celda;
} BrazoArgs;

// Manejador de señal
void cleanup_handler(int sig) {
    (void)sig;
    signal(SIGINT, SIG_IGN);
    
    printf("\n");
    print_timestamp("Deteniendo celda...\n");
    
    celda.celda_activa = 0;
    
    // Cleanup
    if (banda != NULL) shmdt(banda);
    if (stats != NULL) shmdt(stats);
    
    print_timestamp("Celda finalizada.\n");
    exit(0);
}

// Conectar a memoria compartida
int conectar_memoria_compartida() {
    // Conectar a banda
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
    
    // Conectar a semáforos de banda
    semid_banda = semget(KEY_SEM_BANDA, 0, 0666);
    if (semid_banda < 0) {
        perror("semget banda");
        return -1;
    }
    
    // Conectar a estadísticas
    shmid_stats = shmget(KEY_STATS, sizeof(EstadisticasGlobales), 0666);
    if (shmid_stats < 0) {
        perror("shmget stats");
        return -1;
    }
    
    stats = (EstadisticasGlobales *)shmat(shmid_stats, NULL, 0);
    if (stats == (EstadisticasGlobales *)-1) {
        perror("shmat stats");
        return -1;
    }
    
    // Conectar a semáforos de stats
    semid_stats = semget(KEY_SEM_STATS, 0, 0666);
    if (semid_stats < 0) {
        perror("semget stats");
        return -1;
    }
    
    return 0;
}

// Registrar celda en la banda
int registrar_celda() {
    sem_wait_op(semid_banda, 0);
    
    if (banda->num_celdas >= MAX_CELDAS) {
        sem_signal_op(semid_banda, 0);
        fprintf(stderr, "Error: Máximo de celdas alcanzado\n");
        return -1;
    }
    
    banda->pos_celdas[banda->num_celdas] = celda.posicion_banda;
    banda->num_celdas++;
    
    sem_signal_op(semid_banda, 0);
    
    return 0;
}

// Buscar pieza necesaria en la posición
int buscar_pieza_necesaria(int posicion, int* tipo_encontrado) {
    if (posicion < 0 || posicion >= banda->tamanio) {
        return -1;
    }
    
    sem_wait_op(semid_banda, 0);
    
    PosicionBanda* pos = &banda->posiciones[posicion];
    
    // Buscar una pieza que necesitemos
    for (int i = 0; i < pos->count; i++) {
        int tipo = pos->piezas[i];
        if (tipo == VACIO) continue;
        
        int indice = tipo_a_indice(tipo);
        if (indice < 0) continue;
        
        // IMPORTANTE: Verificar si REALMENTE necesitamos esta pieza
        pthread_mutex_lock(&celda.mutex_caja);
        int necesitamos = (celda.caja_actual.piezas_actuales[indice] < 
                          celda.set_config.piezas_requeridas[indice]);
        pthread_mutex_unlock(&celda.mutex_caja);
        
        if (necesitamos) {
            *tipo_encontrado = tipo;
            sem_signal_op(semid_banda, 0);
            return i;  // Índice de la pieza
        }
        // Si no necesitamos esta pieza, seguir buscando otra
    }
    
    sem_signal_op(semid_banda, 0);
    return -1;  // No hay piezas necesarias
}

// Retirar pieza de la banda
int retirar_pieza_banda(int posicion, int tipo) {
    if (posicion < 0 || posicion >= banda->tamanio) {
        return -1;
    }
    
    sem_wait_op(semid_banda, 0);
    
    int resultado = remover_pieza_de_posicion(&banda->posiciones[posicion], tipo);
    
    sem_signal_op(semid_banda, 0);
    
    return resultado;
}

// Depositar pieza en caja
void depositar_en_caja(int tipo) {
    int indice = tipo_a_indice(tipo);
    if (indice < 0) return;
    
    celda.caja_actual.piezas_actuales[indice]++;
    celda.total_piezas_procesadas++;
}

// Verificar si la caja está completa
int caja_completa() {
    for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
        if (celda.caja_actual.piezas_actuales[i] < celda.set_config.piezas_requeridas[i]) {
            return 0;
        }
    }
    return 1;
}

// Determinar brazo con más piezas procesadas (para balance)
int obtener_brazo_mas_ocupado() {
    int max_piezas = -1;
    int brazo_max = -1;
    
    pthread_mutex_lock(&celda.mutex_brazos);
    
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        if (celda.brazos[i].piezas_procesadas > max_piezas) {
            max_piezas = celda.brazos[i].piezas_procesadas;
            brazo_max = i;
        }
    }
    
    pthread_mutex_unlock(&celda.mutex_brazos);
    
    return brazo_max;
}

// Verificar si debe aplicarse balance (cada Y piezas)
int debe_balancear(int mi_id) {
    pthread_mutex_lock(&celda.mutex_balance);
    
    int total = celda.piezas_totales_procesadas;
    int checkpoint = celda.ultimo_checkpoint;
    
    // Cada Y_TIPOS_PIEZAS piezas procesadas
    if (total - checkpoint >= Y_TIPOS_PIEZAS) {
        celda.ultimo_checkpoint = total;
        pthread_mutex_unlock(&celda.mutex_balance);
        
        // Determinar si este brazo es el más ocupado
        int brazo_max = obtener_brazo_mas_ocupado();
        
        if (brazo_max == mi_id) {
            return 1;  // Este brazo debe suspenderse
        }
    } else {
        pthread_mutex_unlock(&celda.mutex_balance);
    }
    
    return 0;  // No suspender
}

// Validar caja con operador humano
void validar_caja() {
    printf("[CELDA %d] 📦 Caja completa, notificando operador...\n", celda.id_celda);
    
    // Tiempo aleatorio entre 0 y MAX_DELTA_T1
    int tiempo_operador = rand() % (MAX_DELTA_T1 + 1);
    usleep(tiempo_operador);
    
    // Verificar si es correcta
    int correcta = 1;
    for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
        if (celda.caja_actual.piezas_actuales[i] != celda.set_config.piezas_requeridas[i]) {
            correcta = 0;
            break;
        }
    }
    
    if (correcta) {
        printf("[OPERADOR] ✅ OK - Caja #%d correcta\n", celda.cajas_completadas + 1);
        celda.cajas_completadas++;
        
        sem_wait_op(semid_stats, 0);
        stats->cajas_ok++;
        sem_signal_op(semid_stats, 0);
    } else {
        printf("[OPERADOR] ❌ FAIL - Caja con errores\n");
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
        
        sem_wait_op(semid_stats, 0);
        stats->cajas_fail++;
        sem_signal_op(semid_stats, 0);
    }
    
    // Reiniciar caja
    memset(&celda.caja_actual, 0, sizeof(EstadoCaja));
    printf("[CELDA %d] 🔄 Nueva caja iniciada\n", celda.id_celda);
}

// Thread de un brazo robótico
void* brazo_worker(void* arg) {
    BrazoArgs* args = (BrazoArgs*)arg;
    int mi_id = args->id_brazo;
    
    printf("[BRAZO %d] Iniciado\n", mi_id);
    
    while (celda.celda_activa && banda->activa > 0) {
        // 1. Buscar pieza necesaria
        int tipo_pieza = VACIO;
        int idx = buscar_pieza_necesaria(celda.posicion_banda, &tipo_pieza);
        
        if (idx >= 0 && tipo_pieza != VACIO) {
            // 2. Esperar permiso para retirar (máximo 2 brazos)
            sem_wait(&celda.sem_retirar);
            
            // 3. VERIFICAR DE NUEVO antes de retirar (por si otro brazo ya tomó una)
            pthread_mutex_lock(&celda.mutex_caja);
            int indice = tipo_a_indice(tipo_pieza);
            int aun_necesitamos = (celda.caja_actual.piezas_actuales[indice] < 
                                   celda.set_config.piezas_requeridas[indice]);
            pthread_mutex_unlock(&celda.mutex_caja);
            
            if (!aun_necesitamos) {
                // Ya no necesitamos esta pieza, dejarla pasar
                sem_post(&celda.sem_retirar);
                usleep(10000);  // Pequeña espera
                continue;
            }
            
            // 4. Retirar pieza de la banda
            if (retirar_pieza_banda(celda.posicion_banda, tipo_pieza) == 0) {
                usleep(TIEMPO_AGARRE);  // 10ms para agarrar
                
                // 5. Liberar semáforo de retirar
                sem_post(&celda.sem_retirar);
                
                // 6. Esperar permiso para depositar (solo 1 a la vez)
                pthread_mutex_lock(&celda.mutex_caja);
                
                // 7. VERIFICAR UNA VEZ MÁS antes de depositar
                if (celda.caja_actual.piezas_actuales[indice] < 
                    celda.set_config.piezas_requeridas[indice]) {
                    
                    // 8. Depositar en caja
                    depositar_en_caja(tipo_pieza);
                    
                    pthread_mutex_lock(&celda.mutex_brazos);
                    celda.brazos[mi_id].piezas_procesadas++;
                    pthread_mutex_unlock(&celda.mutex_brazos);
                    
                    usleep(TIEMPO_DEPOSITO);  // 15ms para depositar
                    
                    // 9. Verificar si caja completa
                    if (caja_completa()) {
                        validar_caja();
                    }
                } else {
                    // Otro brazo ya depositó, esta pieza sobra
                    // (No debería pasar con las verificaciones, pero por seguridad)
                    printf("[BRAZO %d] ⚠️ Pieza %s sobra, se perdió\n", 
                           mi_id, nombre_pieza(tipo_pieza));
                }
                
                pthread_mutex_unlock(&celda.mutex_caja);
                
            } else {
                // No se pudo retirar (otra thread la tomó)
                sem_post(&celda.sem_retirar);
            }
        } else {
            // No hay piezas necesarias, esperar un poco
            usleep(50000);  // 50ms
        }
    }
    
    printf("[BRAZO %d] Finalizado - Procesó %d piezas\n", 
           mi_id, celda.brazos[mi_id].piezas_procesadas);
    
    return NULL;
}

// Inicializar celda
void inicializar_celda(int id, int posicion, int pzA, int pzB, int pzC, int pzD) {
    celda.id_celda = id;
    celda.posicion_banda = posicion;
    celda.celda_activa = 1;
    celda.cajas_completadas = 0;
    celda.cajas_fallidas = 0;
    celda.total_piezas_procesadas = 0;
    
    // Configurar SET
    celda.set_config.piezas_requeridas[0] = pzA;
    celda.set_config.piezas_requeridas[1] = pzB;
    celda.set_config.piezas_requeridas[2] = pzC;
    celda.set_config.piezas_requeridas[3] = pzD;
    celda.set_config.total_piezas = pzA + pzB + pzC + pzD;
    
    // Inicializar caja
    memset(&celda.caja_actual, 0, sizeof(EstadoCaja));
    
    // Inicializar brazos
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        celda.brazos[i].id_brazo = i;
        celda.brazos[i].piezas_procesadas = 0;
        celda.brazos[i].suspendido = 0;
    }
    
    // Inicializar mutex y semáforos
    pthread_mutex_init(&celda.mutex_caja, NULL);
    pthread_mutex_init(&celda.mutex_brazos, NULL);
    pthread_mutex_init(&celda.mutex_balance, NULL);
    sem_init(&celda.sem_retirar, 0, 2);  // Máximo 2 brazos retirando
    
    // Inicializar balance
    celda.piezas_totales_procesadas = 0;
    celda.ultimo_checkpoint = 0;
}

// Ejecutar celda
void ejecutar_celda() {
    pthread_t threads[BRAZOS_POR_CELDA];
    BrazoArgs args[BRAZOS_POR_CELDA];
    
    print_timestamp("Celda iniciada\n");
    printf("Configuración:\n");
    printf("  ID Celda: %d\n", celda.id_celda);
    printf("  Posición en banda: %d\n", celda.posicion_banda);
    printf("  SET requerido: A=%d, B=%d, C=%d, D=%d (Total: %d piezas)\n",
           celda.set_config.piezas_requeridas[0],
           celda.set_config.piezas_requeridas[1],
           celda.set_config.piezas_requeridas[2],
           celda.set_config.piezas_requeridas[3],
           celda.set_config.total_piezas);
    printf("  Brazos robóticos: %d\n", BRAZOS_POR_CELDA);
    printf("  Restricción: Máximo 2 brazos retiran, 1 deposita\n");
    printf("\n");
    
    // Crear threads para los brazos
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        args[i].id_brazo = i;
        args[i].celda = &celda;
        
        if (pthread_create(&threads[i], NULL, brazo_worker, &args[i]) != 0) {
            perror("pthread_create");
            celda.celda_activa = 0;
            return;
        }
    }
    
    printf("[CELDA %d] 🤖 Todos los brazos activos\n", celda.id_celda);
    printf("[CELDA %d] Esperando piezas en posición %d...\n\n", 
           celda.id_celda, celda.posicion_banda);
    
    // Esperar a que termine (Ctrl+C o banda se detenga)
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        pthread_join(threads[i], NULL);
    }
    
    // Mostrar resumen
    printf("\n");
    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║          RESUMEN DETALLADO CELDA %d                        ║\n", celda.id_celda);
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("\n");
    
    // Producción
    printf("📦 PRODUCCIÓN:\n");
    printf("   Cajas completadas OK: %d\n", celda.cajas_completadas);
    printf("   Cajas con errores: %d\n", celda.cajas_fallidas);
    printf("   Total piezas procesadas: %d\n", celda.total_piezas_procesadas);
    
    if (celda.cajas_completadas + celda.cajas_fallidas > 0) {
        float tasa_exito = (float)celda.cajas_completadas / 
                          (celda.cajas_completadas + celda.cajas_fallidas) * 100;
        printf("   Tasa de éxito: %.1f%%\n", tasa_exito);
    }
    printf("\n");
    
    // Estadísticas por brazo
    printf("🤖 ESTADÍSTICAS POR BRAZO:\n");
    int total_brazo = 0;
    int min_piezas = 999999;
    int max_piezas = 0;
    
    for (int i = 0; i < BRAZOS_POR_CELDA; i++) {
        int piezas = celda.brazos[i].piezas_procesadas;
        printf("   Brazo %d: %d piezas procesadas", i, piezas);
        
        total_brazo += piezas;
        if (piezas < min_piezas) min_piezas = piezas;
        if (piezas > max_piezas) max_piezas = piezas;
        
        // Mostrar porcentaje
        if (celda.total_piezas_procesadas > 0) {
            float porcentaje = (float)piezas / celda.total_piezas_procesadas * 100;
            printf(" (%.1f%%)", porcentaje);
        }
        printf("\n");
    }
    
    printf("\n");
    printf("⚖️  BALANCE DE CARGA:\n");
    if (BRAZOS_POR_CELDA > 0) {
        float promedio = (float)total_brazo / BRAZOS_POR_CELDA;
        float desbalance = max_piezas - min_piezas;
        float desbalance_pct = (promedio > 0) ? (desbalance / promedio * 100) : 0;
        
        printf("   Promedio por brazo: %.1f piezas\n", promedio);
        printf("   Mínimo: %d | Máximo: %d | Diferencia: %.0f\n", 
               min_piezas, max_piezas, desbalance);
        printf("   Desbalance: %.1f%%", desbalance_pct);
        
        if (desbalance_pct < 10) {
            printf(" ✅ (Excelente)\n");
        } else if (desbalance_pct < 25) {
            printf(" ✓ (Bueno)\n");
        } else if (desbalance_pct < 50) {
            printf(" ⚠ (Regular)\n");
        } else {
            printf(" ❌ (Malo)\n");
        }
    }
    
    printf("\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
}

int main(int argc, char *argv[]) {
    // Validar argumentos
    if (argc != 7) {
        fprintf(stderr, "Uso: %s <id_celda> <posicion> <pzA> <pzB> <pzC> <pzD>\n", argv[0]);
        fprintf(stderr, "Ejemplo: %s 1 20 3 2 4 1\n", argv[0]);
        fprintf(stderr, "\n");
        fprintf(stderr, "Parámetros:\n");
        fprintf(stderr, "  id_celda: ID único de la celda (1-10)\n");
        fprintf(stderr, "  posicion: Posición en la banda donde captura (0-%d)\n", MAX_BANDA-1);
        fprintf(stderr, "  pzA, pzB, pzC, pzD: Piezas requeridas por set\n");
        exit(EXIT_FAILURE);
    }
    
    int id = atoi(argv[1]);
    int posicion = atoi(argv[2]);
    int pzA = atoi(argv[3]);
    int pzB = atoi(argv[4]);
    int pzC = atoi(argv[5]);
    int pzD = atoi(argv[6]);
    
    // Validar valores
    if (id < 1 || id > 10) {
        fprintf(stderr, "Error: id_celda debe estar entre 1 y 10\n");
        exit(EXIT_FAILURE);
    }
    
    if (posicion < 0 || posicion >= MAX_BANDA) {
        fprintf(stderr, "Error: posicion debe estar entre 0 y %d\n", MAX_BANDA-1);
        exit(EXIT_FAILURE);
    }
    
    if (pzA < 1 || pzB < 1 || pzC < 1 || pzD < 1) {
        fprintf(stderr, "Error: Todas las piezas deben ser >= 1\n");
        exit(EXIT_FAILURE);
    }
    
    // Configurar señales
    signal(SIGINT, cleanup_handler);
    signal(SIGTERM, cleanup_handler);
    
    // Inicializar generador aleatorio
    srand(time(NULL) + id);
    
    // Conectar a memoria compartida
    if (conectar_memoria_compartida() < 0) {
        fprintf(stderr, "Error: No se pudo conectar al sistema\n");
        fprintf(stderr, "Asegúrate de que banda y dispensadores estén ejecutándose.\n");
        exit(EXIT_FAILURE);
    }
    
    // Inicializar celda
    inicializar_celda(id, posicion, pzA, pzB, pzC, pzD);
    
    // Registrar en la banda
    if (registrar_celda() < 0) {
        fprintf(stderr, "Error: No se pudo registrar la celda\n");
        exit(EXIT_FAILURE);
    }
    
    print_timestamp("Celda registrada en el sistema\n");
    
    // Ejecutar celda
    ejecutar_celda();
    
    // Cleanup
    pthread_mutex_destroy(&celda.mutex_caja);
    pthread_mutex_destroy(&celda.mutex_brazos);
    pthread_mutex_destroy(&celda.mutex_balance);
    sem_destroy(&celda.sem_retirar);
    
    if (banda != NULL) shmdt(banda);
    if (stats != NULL) shmdt(stats);
    
    return 0;
}