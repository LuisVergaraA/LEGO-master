#include "common.h"

// Variables globales
BandaTransportadora *banda = NULL;
int shmid_banda = -1;
int semid_banda = -1;

// Variable para estadísticas de piezas al tacho
EstadisticasGlobales *stats = NULL;
int shmid_stats = -1;
int semid_stats = -1;

// Manejador de señal para limpieza
void cleanup_handler(int sig) {
    (void)sig;
    signal(SIGINT, SIG_IGN);
    printf("\n");
    print_timestamp("Deteniendo banda transportadora...\n");
    
    if (banda != NULL) {
        banda->activa = -1;
        shmdt(banda);
    }
    
    if (stats != NULL) {
        shmdt(stats);
    }
    
    // Eliminar recursos IPC
    if (shmid_banda != -1) {
        shmctl(shmid_banda, IPC_RMID, NULL);
    }
    
    if (semid_banda != -1) {
        semctl(semid_banda, 0, IPC_RMID);
    }
    
    print_timestamp("Banda finalizada. Recursos liberados.\n");
    exit(0);
}

// Inicializar la banda transportadora
int inicializar_banda(int tamanio, int velocidad_ms) {
    // Crear memoria compartida
    shmid_banda = shmget(KEY_BANDA, sizeof(BandaTransportadora), IPC_CREAT | 0666);
    if (shmid_banda < 0) {
        perror("shmget banda");
        return -1;
    }
    
    banda = (BandaTransportadora *)shmat(shmid_banda, NULL, 0);
    if (banda == (BandaTransportadora *)-1) {
        perror("shmat banda");
        return -1;
    }
    
    // Inicializar estructura
    banda->tamanio = tamanio;
    banda->velocidad_ms = velocidad_ms;
    banda->activa = 1;
    banda->cabeza = 0;
    banda->num_celdas = 0;
    
    // Limpiar todas las posiciones
    for (int i = 0; i < tamanio; i++) {
        limpiar_posicion(&banda->posiciones[i]);
    }
    
    for (int i = 0; i < MAX_CELDAS; i++) {
        banda->pos_celdas[i] = -1;
    }
    
    // Crear conjunto de semáforos
    semid_banda = semget(KEY_SEM_BANDA, MAX_BANDA + 1, IPC_CREAT | 0666);
    if (semid_banda < 0) {
        perror("semget banda");
        return -1;
    }
    
    // Inicializar semáforos
    sem_init_value(semid_banda, 0, 1); // Semáforo general
    for (int i = 1; i <= tamanio; i++) {
        sem_init_value(semid_banda, i, 1); // Mutex por posición
    }
    
    return 0;
}

// Conectar a estadísticas globales
void conectar_estadisticas() {
    shmid_stats = shmget(KEY_STATS, sizeof(EstadisticasGlobales), 0666);
    if (shmid_stats >= 0) {
        stats = (EstadisticasGlobales *)shmat(shmid_stats, NULL, 0);
        if (stats == (EstadisticasGlobales *)-1) {
            stats = NULL;
        }
        
        semid_stats = semget(KEY_SEM_STATS, 0, 0666);
        if (semid_stats < 0) {
            stats = NULL;
        }
    }
}

// Mover la banda un paso (shift circular REAL)
void mover_banda() {
    sem_wait_op(semid_banda, 0);
    
    // Guardar la última posición (en vez de tirarla al tacho)
    PosicionBanda pieza_final = banda->posiciones[banda->tamanio - 1];
    
    // Desplazar todas las posiciones un paso adelante
    for (int i = banda->tamanio - 1; i > 0; i--) {
        banda->posiciones[i] = banda->posiciones[i - 1];
    }
    
    // BANDA CIRCULAR: Las piezas del final regresan a la posición 0
    // Pero SOLO si no hay nuevas piezas siendo dispensadas
    if (banda->posiciones[0].count == 0) {
        // Posición 0 vacía, podemos poner las piezas que venían del final
        banda->posiciones[0] = pieza_final;
    } else {
        // Ya hay piezas nuevas en pos 0, las del final van al tacho
        if (pieza_final.count > 0 && stats != NULL) {
            sem_wait_op(semid_stats, 0);
            for (int i = 0; i < pieza_final.count; i++) {
                int tipo = pieza_final.piezas[i];
                if (tipo != VACIO) {
                    int indice = tipo_a_indice(tipo);
                    if (indice >= 0 && indice < MAX_TIPOS_PIEZAS) {
                        stats->piezas_sobrantes[indice]++;
                        printf("  [TACHO] Pieza tipo %s (banda saturada)\n", 
                               nombre_pieza(tipo));
                    }
                }
            }
            sem_signal_op(semid_stats, 0);
        }
    }
    
    banda->cabeza = 0;
    sem_signal_op(semid_banda, 0);
}

// Mostrar estado de la banda
void mostrar_estado() {
    printf("\n═══════════════════════════════════════════════════════════\n");
    print_timestamp("Estado de la Banda Transportadora\n");
    printf("═══════════════════════════════════════════════════════════\n");
    printf("Tamaño: %d pasos | Velocidad: %d ms/paso | Estado: %s\n", 
           banda->tamanio, banda->velocidad_ms,
           banda->activa > 0 ? "ACTIVA" : "DETENIDA");
    
    // Mostrar primeras 20 posiciones
    printf("Posiciones [0-19]: ");
    for (int i = 0; i < 20 && i < banda->tamanio; i++) {
        if (banda->posiciones[i].count == 0) {
            printf("· ");
        } else if (banda->posiciones[i].count == 1) {
            printf("%s ", nombre_pieza(banda->posiciones[i].piezas[0]));
        } else {
            printf("[");
            for (int j = 0; j < banda->posiciones[i].count && j < 3; j++) {
                printf("%s", nombre_pieza(banda->posiciones[i].piezas[j]));
            }
            if (banda->posiciones[i].count > 3) printf("+");
            printf("] ");
        }
    }
    if (banda->tamanio > 20) printf("...");
    printf("\n");
    
    // Mostrar celdas activas
    printf("Celdas activas: %d", banda->num_celdas);
    if (banda->num_celdas > 0) {
        printf(" en posiciones: ");
        for (int i = 0; i < banda->num_celdas; i++) {
            printf("[%d] ", banda->pos_celdas[i]);
        }
    }
    printf("\n═══════════════════════════════════════════════════════════\n\n");
}

// Loop principal de la banda
void ejecutar_banda() {
    int ciclos = 0;
    int mostrar_cada = 10;
    
    print_timestamp("Banda transportadora iniciada\n");
    printf("Tamaño: %d pasos, Velocidad: %d ms\n", 
           banda->tamanio, banda->velocidad_ms);
    printf("Esperando dispensadores y celdas...\n");
    printf("Presione Ctrl+C para detener.\n\n");
    
    // Intentar conectar a estadísticas (pueden no existir aún)
    sleep(1);
    conectar_estadisticas();
    
    while (banda->activa > 0) {
        usleep(banda->velocidad_ms * 1000);
        mover_banda();
        ciclos++;
        
        if (ciclos % mostrar_cada == 0) {
            mostrar_estado();
        }
    }
    
    print_timestamp("Banda detenida.\n");
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Uso: %s <tamaño_banda> <velocidad_ms>\n", argv[0]);
        fprintf(stderr, "Ejemplo: %s 50 100\n", argv[0]);
        fprintf(stderr, "  tamaño_banda: número de pasos (10-200)\n");
        fprintf(stderr, "  velocidad_ms: milisegundos por paso (50-1000)\n");
        exit(EXIT_FAILURE);
    }
    
    int tamanio = atoi(argv[1]);
    int velocidad = atoi(argv[2]);
    
    if (tamanio < 10 || tamanio > MAX_BANDA) {
        fprintf(stderr, "Error: tamaño debe estar entre 10 y %d\n", MAX_BANDA);
        exit(EXIT_FAILURE);
    }
    
    if (velocidad < 50 || velocidad > 1000) {
        fprintf(stderr, "Error: velocidad debe estar entre 50 y 1000 ms\n");
        exit(EXIT_FAILURE);
    }
    
    signal(SIGINT, cleanup_handler);
    signal(SIGTERM, cleanup_handler);
    
    if (inicializar_banda(tamanio, velocidad) < 0) {
        fprintf(stderr, "Error al inicializar la banda\n");
        exit(EXIT_FAILURE);
    }
    
    ejecutar_banda();
    cleanup_handler(0);
    
    return 0;
}