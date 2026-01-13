#include "common.h"

// Variables globales
BandaTransportadora *banda = NULL;
EstadisticasGlobales *stats = NULL;
int shmid_banda = -1;
int shmid_stats = -1;
int semid_banda = -1;
int semid_stats = -1;

// Configuración de dispensado
typedef struct {
    int num_dispensadores;
    int num_sets;
    int piezas_por_set[MAX_TIPOS_PIEZAS];  // [A, B, C, D]
    int piezas_restantes[MAX_TIPOS_PIEZAS];
    int intervalo_us;  // Intervalo entre dispensados en microsegundos
} ConfigDispensadores;

ConfigDispensadores config;

// Manejador de señal para limpieza
void cleanup_handler(int sig) {
    (void)sig;
    signal(SIGINT, SIG_IGN);
    
    printf("\n");
    print_timestamp("Deteniendo dispensadores...\n");
    
    if (stats != NULL) {
        stats->sistema_activo = 0;
    }
    
    // Detach de memoria compartida
    if (banda != NULL) {
        shmdt(banda);
    }
    if (stats != NULL) {
        shmdt(stats);
    }
    
    print_timestamp("Dispensadores finalizados.\n");
    exit(0);
}

// Inicializar conexión con memoria compartida
int conectar_memoria_compartida() {
    // Conectar a banda
    shmid_banda = shmget(KEY_BANDA, sizeof(BandaTransportadora), 0666);
    if (shmid_banda < 0) {
        perror("shmget banda");
        fprintf(stderr, "Error: ¿La banda está ejecutándose?\n");
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
    
    // Crear memoria compartida para estadísticas
    shmid_stats = shmget(KEY_STATS, sizeof(EstadisticasGlobales), IPC_CREAT | 0666);
    if (shmid_stats < 0) {
        perror("shmget stats");
        return -1;
    }
    
    stats = (EstadisticasGlobales *)shmat(shmid_stats, NULL, 0);
    if (stats == (EstadisticasGlobales *)-1) {
        perror("shmat stats");
        return -1;
    }
    
    // Crear semáforo para estadísticas
    semid_stats = semget(KEY_SEM_STATS, 1, IPC_CREAT | 0666);
    if (semid_stats < 0) {
        perror("semget stats");
        return -1;
    }
    
    sem_init_value(semid_stats, 0, 1);
    
    return 0;
}

// Inicializar estadísticas
void inicializar_estadisticas() {
    sem_wait_op(semid_stats, 0);
    
    stats->cajas_ok = 0;
    stats->cajas_fail = 0;
    stats->total_piezas_dispensadas = 0;
    stats->sistema_activo = 1;
    stats->inicio = time(NULL);
    
    for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
        stats->piezas_sobrantes[i] = 0;
    }
    
    sem_signal_op(semid_stats, 0);
}

// Insertar una pieza en la banda (posición 0)
int insertar_pieza_en_banda(int tipo_pieza) {
    if (tipo_pieza == VACIO) {
        return 0;
    }
    
    // Proteger acceso a la banda
    sem_wait_op(semid_banda, 0);
    
    // Insertar en la posición 0 (donde entran las piezas)
    banda->posiciones[0] = tipo_pieza;
    
    sem_signal_op(semid_banda, 0);
    
    // Actualizar estadísticas
    sem_wait_op(semid_stats, 0);
    stats->total_piezas_dispensadas++;
    sem_signal_op(semid_stats, 0);
    
    return 1;
}

// Dispensar piezas en un ciclo
void ciclo_dispensado() {
    int total_piezas = config.piezas_restantes[0] + config.piezas_restantes[1] +
                       config.piezas_restantes[2] + config.piezas_restantes[3];
    
    printf("  Dispensando: ");
    
    for (int i = 0; i < config.num_dispensadores; i++) {
        // Generar tipo de pieza aleatorio (0-4, donde 0 = sin pieza)
        int tipo = rand() % 5;
        
        // Si es un tipo válido (1-4) y quedan piezas de ese tipo
        if (tipo >= 1 && tipo <= 4) {
            int indice = tipo_a_indice(tipo);
            if (config.piezas_restantes[indice] > 0) {
                // Dispensar la pieza
                insertar_pieza_en_banda(tipo);
                config.piezas_restantes[indice]--;
                printf("%s ", nombre_pieza(tipo));
            } else {
                printf("· ");
            }
        } else {
            // No dispensar pieza (espacio vacío)
            printf("· ");
        }
    }
    
    printf("| Restantes: ");
    for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
        printf("%s:%d ", nombre_pieza(indice_a_tipo(i)), config.piezas_restantes[i]);
    }
    printf("\n");
}

// Loop principal de dispensado
void ejecutar_dispensadores() {
    print_timestamp("Dispensadores iniciados\n");
    printf("Configuración:\n");
    printf("  Dispensadores: %d\n", config.num_dispensadores);
    printf("  Sets a producir: %d\n", config.num_sets);
    printf("  Piezas por set: A=%d, B=%d, C=%d, D=%d\n",
           config.piezas_por_set[0], config.piezas_por_set[1],
           config.piezas_por_set[2], config.piezas_por_set[3]);
    printf("  Total de piezas: %d\n",
           config.piezas_restantes[0] + config.piezas_restantes[1] +
           config.piezas_restantes[2] + config.piezas_restantes[3]);
    printf("  Intervalo: %d μs\n", config.intervalo_us);
    printf("\n");
    
    // Esperar un momento para que la banda esté lista
    sleep(1);
    
    int ciclo = 0;
    int total_inicial = config.piezas_restantes[0] + config.piezas_restantes[1] +
                        config.piezas_restantes[2] + config.piezas_restantes[3];
    
    while (banda->activa > 0) {
        int total_restante = config.piezas_restantes[0] + config.piezas_restantes[1] +
                             config.piezas_restantes[2] + config.piezas_restantes[3];
        
        // Si ya no quedan piezas, terminar
        if (total_restante <= 0) {
            print_timestamp("Todas las piezas han sido dispensadas\n");
            break;
        }
        
        // Esperar según el intervalo configurado
        usleep(config.intervalo_us);
        
        ciclo++;
        printf("[Ciclo %d] ", ciclo);
        ciclo_dispensado();
        
        // Mostrar progreso cada 20 ciclos
        if (ciclo % 20 == 0) {
            int dispensadas = total_inicial - total_restante;
            float progreso = (float)dispensadas / total_inicial * 100;
            printf("\n--- Progreso: %.1f%% (%d/%d piezas) ---\n\n",
                   progreso, dispensadas, total_inicial);
        }
    }
    
    // Señalizar fin de dispensado
    print_timestamp("Dispensado completado\n");
    printf("\nResumen:\n");
    printf("  Total dispensado: %d piezas\n", stats->total_piezas_dispensadas);
    printf("  Ciclos ejecutados: %d\n", ciclo);
    
    // Dar tiempo para que las piezas se procesen
    print_timestamp("Esperando que las piezas se procesen...\n");
    sleep(2);
}

int main(int argc, char *argv[]) {
    // Validar argumentos
    if (argc != 8) {
        fprintf(stderr, "Uso: %s <#dispensadores> <#sets> <pzA> <pzB> <pzC> <pzD> <intervalo_us>\n", argv[0]);
        fprintf(stderr, "Ejemplo: %s 4 5 3 2 4 1 50000\n", argv[0]);
        fprintf(stderr, "\n");
        fprintf(stderr, "Parámetros:\n");
        fprintf(stderr, "  #dispensadores: Número de dispensadores (1-10)\n");
        fprintf(stderr, "  #sets: Cantidad de sets a producir (1-100)\n");
        fprintf(stderr, "  pzA, pzB, pzC, pzD: Piezas por set de cada tipo (1-20)\n");
        fprintf(stderr, "  intervalo_us: Microsegundos entre dispensados (10000-1000000)\n");
        exit(EXIT_FAILURE);
    }
    
    // Parsear argumentos
    config.num_dispensadores = atoi(argv[1]);
    config.num_sets = atoi(argv[2]);
    config.piezas_por_set[0] = atoi(argv[3]);  // A
    config.piezas_por_set[1] = atoi(argv[4]);  // B
    config.piezas_por_set[2] = atoi(argv[5]);  // C
    config.piezas_por_set[3] = atoi(argv[6]);  // D
    config.intervalo_us = atoi(argv[7]);
    
    // Validar valores
    if (config.num_dispensadores < 1 || config.num_dispensadores > 10) {
        fprintf(stderr, "Error: número de dispensadores debe estar entre 1 y 10\n");
        exit(EXIT_FAILURE);
    }
    
    if (config.num_sets < 1 || config.num_sets > 100) {
        fprintf(stderr, "Error: número de sets debe estar entre 1 y 100\n");
        exit(EXIT_FAILURE);
    }
    
    for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
        if (config.piezas_por_set[i] < 1 || config.piezas_por_set[i] > 20) {
            fprintf(stderr, "Error: piezas por set deben estar entre 1 y 20\n");
            exit(EXIT_FAILURE);
        }
    }
    
    if (config.intervalo_us < 10000 || config.intervalo_us > 1000000) {
        fprintf(stderr, "Error: intervalo debe estar entre 10000 y 1000000 μs\n");
        exit(EXIT_FAILURE);
    }
    
    // Calcular total de piezas
    for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
        config.piezas_restantes[i] = config.num_sets * config.piezas_por_set[i];
    }
    
    // Configurar manejador de señales
    signal(SIGINT, cleanup_handler);
    signal(SIGTERM, cleanup_handler);
    
    // Inicializar generador de números aleatorios
    srand(time(NULL));
    
    // Conectar a memoria compartida
    if (conectar_memoria_compartida() < 0) {
        fprintf(stderr, "Error: No se pudo conectar a la banda\n");
        fprintf(stderr, "Asegúrate de que el proceso 'banda' esté ejecutándose.\n");
        exit(EXIT_FAILURE);
    }
    
    print_timestamp("Conectado a la banda transportadora\n");
    
    // Inicializar estadísticas
    inicializar_estadisticas();
    
    // Ejecutar loop principal
    ejecutar_dispensadores();
    
    // Cleanup
    cleanup_handler(0);
    
    return 0;
}