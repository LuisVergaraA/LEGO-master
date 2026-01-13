#include "common.h"

// Variables globales
BandaTransportadora *banda = NULL;
int shmid_banda = -1;
int semid_banda = -1;

// Manejador de señal para limpieza
void cleanup_handler(int sig) {
    (void)sig; // Evitar warning de parámetro no usado
    signal(SIGINT, SIG_IGN);
    printf("\n");
    print_timestamp("Deteniendo banda transportadora...\n");
    
    if (banda != NULL) {
        banda->activa = -1; // Señal de terminación
        
        // Detach de memoria compartida
        if (shmdt(banda) == -1) {
            perror("shmdt banda");
        }
    }
    
    // Eliminar recursos IPC
    if (shmid_banda != -1) {
        if (shmctl(shmid_banda, IPC_RMID, NULL) == -1) {
            perror("shmctl IPC_RMID banda");
        }
    }
    
    if (semid_banda != -1) {
        if (semctl(semid_banda, 0, IPC_RMID) == -1) {
            perror("semctl IPC_RMID");
        }
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
    
    // Attach a memoria compartida
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
        banda->posiciones[i] = VACIO;
    }
    
    for (int i = 0; i < MAX_CELDAS; i++) {
        banda->pos_celdas[i] = -1;
    }
    
    // Crear conjunto de semáforos
    // sem[0] = mutex para acceso a la banda
    // sem[1..MAX_BANDA] = mutex por cada posición de la banda
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

// Mover la banda un paso (shift circular)
void mover_banda() {
    // Proteger acceso a la banda
    sem_wait_op(semid_banda, 0);
    
    // Guardar la pieza que está al final (caerá al tacho)
    int pieza_final = banda->posiciones[banda->tamanio - 1];
    
    // Desplazar todas las piezas un paso adelante
    for (int i = banda->tamanio - 1; i > 0; i--) {
        banda->posiciones[i] = banda->posiciones[i - 1];
    }
    
    // La posición 0 queda vacía (los dispensadores la llenarán)
    banda->posiciones[0] = VACIO;
    
    // Actualizar cabeza circular
    banda->cabeza = 0;
    
    sem_signal_op(semid_banda, 0);
    
    // Reportar si una pieza cayó al tacho
    if (pieza_final != VACIO && pieza_final != FIN_BANDA) {
        printf("  [TACHO] Pieza tipo %s cayó al final de la banda\n", 
               nombre_pieza(pieza_final));
    }
}

// Mostrar estado de la banda (versión simplificada)
void mostrar_estado() {
    printf("\n═══════════════════════════════════════════════════════════\n");
    print_timestamp("Estado de la Banda Transportadora\n");
    printf("═══════════════════════════════════════════════════════════\n");
    printf("Tamaño: %d pasos | Velocidad: %d ms/paso\n", 
           banda->tamanio, banda->velocidad_ms);
    
    // Mostrar primeras 20 posiciones
    printf("Posiciones [0-19]: ");
    for (int i = 0; i < 20 && i < banda->tamanio; i++) {
        if (banda->posiciones[i] == VACIO) {
            printf("· ");
        } else {
            printf("%s ", nombre_pieza(banda->posiciones[i]));
        }
    }
    if (banda->tamanio > 20) printf("...");
    printf("\n");
    
    // Mostrar celdas activas
    printf("Celdas activas: %d\n", banda->num_celdas);
    if (banda->num_celdas > 0) {
        printf("Posiciones: ");
        for (int i = 0; i < banda->num_celdas; i++) {
            printf("[%d] ", banda->pos_celdas[i]);
        }
        printf("\n");
    }
    printf("═══════════════════════════════════════════════════════════\n\n");
}

// Loop principal de la banda
void ejecutar_banda() {
    int ciclos = 0;
    int mostrar_cada = 10; // Mostrar estado cada 10 ciclos
    
    print_timestamp("Banda transportadora iniciada\n");
    printf("Tamaño: %d pasos, Velocidad: %d ms\n", 
           banda->tamanio, banda->velocidad_ms);
    printf("Esperando dispensadores y celdas...\n");
    printf("Presione Ctrl+C para detener.\n\n");
    
    while (banda->activa > 0) {
        // Esperar según velocidad configurada
        usleep(banda->velocidad_ms * 1000);
        
        // Mover la banda un paso
        mover_banda();
        
        ciclos++;
        
        // Mostrar estado periódicamente
        if (ciclos % mostrar_cada == 0) {
            mostrar_estado();
        }
    }
    
    print_timestamp("Banda detenida.\n");
}

int main(int argc, char *argv[]) {
    // Validar argumentos
    if (argc != 3) {
        fprintf(stderr, "Uso: %s <tamaño_banda> <velocidad_ms>\n", argv[0]);
        fprintf(stderr, "Ejemplo: %s 50 100\n", argv[0]);
        fprintf(stderr, "  tamaño_banda: número de pasos (10-200)\n");
        fprintf(stderr, "  velocidad_ms: milisegundos por paso (50-1000)\n");
        exit(EXIT_FAILURE);
    }
    
    int tamanio = atoi(argv[1]);
    int velocidad = atoi(argv[2]);
    
    // Validar valores
    if (tamanio < 10 || tamanio > MAX_BANDA) {
        fprintf(stderr, "Error: tamaño debe estar entre 10 y %d\n", MAX_BANDA);
        exit(EXIT_FAILURE);
    }
    
    if (velocidad < 50 || velocidad > 1000) {
        fprintf(stderr, "Error: velocidad debe estar entre 50 y 1000 ms\n");
        exit(EXIT_FAILURE);
    }
    
    // Configurar manejador de señales
    signal(SIGINT, cleanup_handler);
    signal(SIGTERM, cleanup_handler);
    
    // Inicializar banda
    if (inicializar_banda(tamanio, velocidad) < 0) {
        fprintf(stderr, "Error al inicializar la banda\n");
        exit(EXIT_FAILURE);
    }
    
    // Ejecutar loop principal
    ejecutar_banda();
    
    // Cleanup (aunque el handler se encarga)
    cleanup_handler(0);
    
    return 0;
}