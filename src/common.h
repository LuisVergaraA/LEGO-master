#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/sem.h>
#include <time.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>

// ============= CONSTANTES GLOBALES =============
#define MAX_BANDA 200           // Tamaño máximo de la banda
#define MAX_CELDAS 10           // Máximo de celdas simultáneas
#define BRAZOS_POR_CELDA 4      // Brazos robóticos por celda
#define MAX_TIPOS_PIEZAS 4      // Tipos de piezas (A, B, C, D)

// Keys para IPC
#define KEY_BANDA 2222          // Memoria compartida: banda transportadora
#define KEY_SEM_BANDA 2223      // Semáforos: sincronización banda
#define KEY_STATS 2224          // Memoria compartida: estadísticas
#define KEY_SEM_STATS 2225      // Semáforos: estadísticas

// Códigos de pieza
#define VACIO 0
#define PIEZA_A 1
#define PIEZA_B 2
#define PIEZA_C 3
#define PIEZA_D 4
#define FIN_BANDA -1            // Señal de terminación

// Tiempos (en microsegundos)
#define TIEMPO_AGARRE 10000     // 10ms para agarrar una pieza
#define TIEMPO_DEPOSITO 15000   // 15ms para depositar en caja
#define MAX_DELTA_T1 2000000    // 2 segundos máximo para cambio de caja
#define DELTA_T2 100000         // 100ms suspensión de brazo sobrecargado

// Balance de brazos
#define Y_TIPOS_PIEZAS 4        // Cada Y=4 piezas totales, revisar balance

// ============= ESTRUCTURAS =============

// Estructura para una posición de banda (múltiples piezas)
#define MAX_PIEZAS_POR_POSICION 10

typedef struct {
    int piezas[MAX_PIEZAS_POR_POSICION];  // Array de piezas en esta posición
    int count;                             // Cantidad actual de piezas
} PosicionBanda;

// Estructura de la banda transportadora en memoria compartida
typedef struct {
    int tamanio;                      // N pasos de la banda
    int velocidad_ms;                 // Velocidad en milisegundos por paso
    int activa;                       // 1 = operando, 0 = detenida, -1 = fin
    PosicionBanda posiciones[MAX_BANDA];  // Arreglo circular de posiciones
    int cabeza;                       // Índice actual de inserción (dispensadores)
    int num_celdas;                   // Número de celdas activas
    int pos_celdas[MAX_CELDAS];       // Posiciones de las celdas en la banda
} BandaTransportadora;

// Configuración de un SET
typedef struct {
    int piezas_requeridas[MAX_TIPOS_PIEZAS]; // [A, B, C, D]
    int total_piezas;
} ConfiguracionSET;

// Estado de una caja en proceso
typedef struct {
    int piezas_actuales[MAX_TIPOS_PIEZAS];
    int completa;               // 0 = en proceso, 1 = completa, -1 = fallida
    pthread_mutex_t mutex;      // Protección del estado de la caja
} EstadoCaja;

// Estadísticas de un brazo robótico
typedef struct {
    int id_brazo;               // 0-3
    int piezas_procesadas;      // Contador total
    int suspendido;             // 0 = activo, 1 = suspendido
    time_t tiempo_suspension;   // Timestamp de suspensión
} EstadoBrazo;

// Estadísticas globales en memoria compartida
typedef struct {
    int cajas_ok;               // Cajas completadas correctamente
    int cajas_fail;             // Cajas con errores
    int piezas_sobrantes[MAX_TIPOS_PIEZAS]; // Piezas que cayeron al tacho
    int total_piezas_dispensadas;
    int sistema_activo;         // 1 = activo, 0 = finalizado
    time_t inicio;              // Timestamp de inicio
} EstadisticasGlobales;

// ============= OPERACIONES DE SEMÁFOROS =============

// Union para semctl (requerido en algunos sistemas)
union semun {
    int val;
    struct semid_ds *buf;
    unsigned short *array;
};

// Inicializar un semáforo
static inline int sem_init_value(int semid, int sem_num, int value) {
    union semun arg;
    arg.val = value;
    return semctl(semid, sem_num, SETVAL, arg);
}

// Operación P (wait/down) - Decrementar semáforo
static inline int sem_wait_op(int semid, int sem_num) {
    struct sembuf op;
    op.sem_num = sem_num;
    op.sem_op = -1;
    op.sem_flg = 0;
    return semop(semid, &op, 1);
}

// Operación V (signal/up) - Incrementar semáforo
static inline int sem_signal_op(int semid, int sem_num) {
    struct sembuf op;
    op.sem_num = sem_num;
    op.sem_op = 1;
    op.sem_flg = 0;
    return semop(semid, &op, 1);
}

// ============= FUNCIONES AUXILIARES =============

// Obtener nombre de tipo de pieza
static inline const char* nombre_pieza(int tipo) {
    switch(tipo) {
        case VACIO: return "VACIO";
        case PIEZA_A: return "A";
        case PIEZA_B: return "B";
        case PIEZA_C: return "C";
        case PIEZA_D: return "D";
        case FIN_BANDA: return "FIN";
        default: return "?";
    }
}

// Convertir tipo a índice (1->0, 2->1, etc.)
static inline int tipo_a_indice(int tipo) {
    if (tipo >= 1 && tipo <= 4) return tipo - 1;
    return -1;
}

// Convertir índice a tipo (0->1, 1->2, etc.)
static inline int indice_a_tipo(int indice) {
    if (indice >= 0 && indice < MAX_TIPOS_PIEZAS) return indice + 1;
    return VACIO;
}

// Imprimir timestamp
static inline void print_timestamp(const char* prefix) {
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    printf("[%02d:%02d:%02d] %s", t->tm_hour, t->tm_min, t->tm_sec, prefix);
}

// Agregar pieza a una posición
static inline int agregar_pieza_a_posicion(PosicionBanda* pos, int tipo) {
    if (pos->count >= MAX_PIEZAS_POR_POSICION) {
        return -1;  // Posición llena
    }
    pos->piezas[pos->count] = tipo;
    pos->count++;
    return 0;
}

// Remover pieza de una posición (por tipo)
static inline int remover_pieza_de_posicion(PosicionBanda* pos, int tipo) {
    for (int i = 0; i < pos->count; i++) {
        if (pos->piezas[i] == tipo) {
            // Shift array hacia la izquierda
            for (int j = i; j < pos->count - 1; j++) {
                pos->piezas[j] = pos->piezas[j + 1];
            }
            pos->count--;
            return 0;
        }
    }
    return -1;  // Pieza no encontrada
}

// Buscar si existe un tipo de pieza en una posición
static inline int buscar_pieza_en_posicion(PosicionBanda* pos, int tipo) {
    for (int i = 0; i < pos->count; i++) {
        if (pos->piezas[i] == tipo) {
            return i;  // Índice donde está la pieza
        }
    }
    return -1;  // No encontrada
}

// Limpiar una posición
static inline void limpiar_posicion(PosicionBanda* pos) {
    pos->count = 0;
    for (int i = 0; i < MAX_PIEZAS_POR_POSICION; i++) {
        pos->piezas[i] = VACIO;
    }
}

#endif // COMMON_H