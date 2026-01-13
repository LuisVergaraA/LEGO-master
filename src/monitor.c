#include "common.h"

// Variables globales
BandaTransportadora *banda = NULL;
EstadisticasGlobales *stats = NULL;
int shmid_banda = -1;
int shmid_stats = -1;
int running = 1;

// Manejador de señal
void cleanup_handler(int sig) {
    (void)sig;
    running = 0;
}

// Limpiar pantalla (ANSI escape codes)
void clear_screen() {
    printf("\033[2J\033[H");
}

// Mover cursor a posición
void move_cursor(int row, int col) {
    printf("\033[%d;%dH", row, col);
}

// Colores ANSI
#define COLOR_RESET   "\033[0m"
#define COLOR_RED     "\033[31m"
#define COLOR_GREEN   "\033[32m"
#define COLOR_YELLOW  "\033[33m"
#define COLOR_BLUE    "\033[34m"
#define COLOR_MAGENTA "\033[35m"
#define COLOR_CYAN    "\033[36m"
#define COLOR_WHITE   "\033[37m"
#define COLOR_BOLD    "\033[1m"

// Obtener color para tipo de pieza
const char* get_color(int tipo) {
    switch(tipo) {
        case PIEZA_A: return COLOR_RED;
        case PIEZA_B: return COLOR_GREEN;
        case PIEZA_C: return COLOR_YELLOW;
        case PIEZA_D: return COLOR_CYAN;
        default: return COLOR_WHITE;
    }
}

// Conectar a memoria compartida
int conectar_memoria() {
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
    
    // Conectar a estadísticas (puede no existir aún)
    shmid_stats = shmget(KEY_STATS, sizeof(EstadisticasGlobales), 0666);
    if (shmid_stats >= 0) {
        stats = (EstadisticasGlobales *)shmat(shmid_stats, NULL, 0);
        if (stats == (EstadisticasGlobales *)-1) {
            stats = NULL;
        }
    }
    
    return 0;
}

// Dibujar borde superior
void dibujar_borde_superior(int ancho) {
    printf("╔");
    for (int i = 0; i < ancho - 2; i++) printf("═");
    printf("╗\n");
}

// Dibujar borde inferior
void dibujar_borde_inferior(int ancho) {
    printf("╚");
    for (int i = 0; i < ancho - 2; i++) printf("═");
    printf("╝\n");
}

// Dibujar línea divisoria
void dibujar_linea_divisoria(int ancho) {
    printf("╠");
    for (int i = 0; i < ancho - 2; i++) printf("═");
    printf("╣\n");
}

// Visualizar la banda
void visualizar_banda() {
    int ancho_display = 80;
    int max_mostrar = 60;  // Mostrar hasta 60 posiciones
    
    // Título
    printf("║");
    printf("%s", COLOR_BOLD);
    printf(" BANDA TRANSPORTADORA ");
    printf("%s", COLOR_RESET);
    printf("%*s", ancho_display - 23, "║\n");
    
    dibujar_linea_divisoria(ancho_display);
    
    // Estado de la banda
    printf("║ Tamaño: %d pasos | Velocidad: %d ms/paso", 
           banda->tamanio, banda->velocidad_ms);
    printf("%*s", ancho_display - 46, "║\n");
    
    printf("║ Celdas activas: %d", banda->num_celdas);
    if (banda->num_celdas > 0) {
        printf(" | Posiciones: ");
        for (int i = 0; i < banda->num_celdas && i < 5; i++) {
            printf("[%d] ", banda->pos_celdas[i]);
        }
    }
    printf("%*s", ancho_display - 60, "║\n");
    
    dibujar_linea_divisoria(ancho_display);
    
    // Visualización de la banda (primeras 60 posiciones)
    int mostrar = (banda->tamanio < max_mostrar) ? banda->tamanio : max_mostrar;
    
    // Cabecera con números de posición
    printf("║ Pos: ");
    for (int i = 0; i < mostrar; i++) {
        if (i % 10 == 0) {
            printf("%s%-2d%s", COLOR_BOLD, i, COLOR_RESET);
        } else {
            printf("  ");
        }
    }
    printf("%*s", ancho_display - 8 - (mostrar * 2), "║\n");
    
    // Piezas en la banda
    printf("║      ");
    for (int i = 0; i < mostrar; i++) {
        int pieza = banda->posiciones[i];
        const char* color = get_color(pieza);
        
        if (pieza == VACIO) {
            printf("· ");
        } else {
            printf("%s%s%s ", color, nombre_pieza(pieza), COLOR_RESET);
        }
    }
    if (banda->tamanio > max_mostrar) {
        printf("...");
    }
    printf("%*s", ancho_display - 8 - (mostrar * 2) - 3, "║\n");
    
    // Indicador de dirección
    printf("║      ");
    for (int i = 0; i < mostrar && i < 20; i++) {
        printf("→ ");
    }
    printf("%*s", ancho_display - 8 - 40, "║\n");
    
    dibujar_linea_divisoria(ancho_display);
}

// Visualizar estadísticas
void visualizar_estadisticas() {
    int ancho_display = 80;
    
    printf("║");
    printf("%s", COLOR_BOLD);
    printf(" ESTADÍSTICAS DEL SISTEMA ");
    printf("%s", COLOR_RESET);
    printf("%*s", ancho_display - 28, "║\n");
    
    dibujar_linea_divisoria(ancho_display);
    
    if (stats != NULL) {
        // Tiempo de ejecución
        time_t now = time(NULL);
        int elapsed = (int)difftime(now, stats->inicio);
        int horas = elapsed / 3600;
        int minutos = (elapsed % 3600) / 60;
        int segundos = elapsed % 60;
        
        printf("║ Tiempo de ejecución: %02d:%02d:%02d", horas, minutos, segundos);
        printf("%*s", ancho_display - 32, "║\n");
        
        printf("║ Estado: %s%s%s",
               stats->sistema_activo ? COLOR_GREEN : COLOR_RED,
               stats->sistema_activo ? "ACTIVO" : "DETENIDO",
               COLOR_RESET);
        printf("%*s", ancho_display - 18 - (stats->sistema_activo ? 0 : 2), "║\n");
        
        dibujar_linea_divisoria(ancho_display);
        
        // Producción
        printf("║ %sCajas completadas OK:%s %d",
               COLOR_GREEN, COLOR_RESET, stats->cajas_ok);
        printf("%*s", ancho_display - 29, "║\n");
        
        printf("║ %sCajas con errores:%s %d",
               COLOR_RED, COLOR_RESET, stats->cajas_fail);
        printf("%*s", ancho_display - 26, "║\n");
        
        printf("║ Total piezas dispensadas: %d",
               stats->total_piezas_dispensadas);
        printf("%*s", ancho_display - 34, "║\n");
        
        dibujar_linea_divisoria(ancho_display);
        
        // Piezas sobrantes
        printf("║ %sPiezas en el tacho:%s", COLOR_YELLOW, COLOR_RESET);
        printf("%*s", ancho_display - 25, "║\n");
        
        int total_sobrantes = 0;
        for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
            total_sobrantes += stats->piezas_sobrantes[i];
        }
        
        printf("║   ");
        for (int i = 0; i < MAX_TIPOS_PIEZAS; i++) {
            const char* color = get_color(indice_a_tipo(i));
            printf("%s%s:%d%s  ", color, nombre_pieza(indice_a_tipo(i)),
                   stats->piezas_sobrantes[i], COLOR_RESET);
        }
        printf("| Total: %d", total_sobrantes);
        printf("%*s", ancho_display - 40, "║\n");
    } else {
        printf("║ %s(Esperando dispensadores...)%s",
               COLOR_YELLOW, COLOR_RESET);
        printf("%*s", ancho_display - 36, "║\n");
    }
}

// Visualizar leyenda
void visualizar_leyenda() {
    int ancho_display = 80;
    
    dibujar_linea_divisoria(ancho_display);
    
    printf("║ %sLEYENDA:%s ", COLOR_BOLD, COLOR_RESET);
    printf("%sA%s=Rojo  ", COLOR_RED, COLOR_RESET);
    printf("%sB%s=Verde  ", COLOR_GREEN, COLOR_RESET);
    printf("%sC%s=Amarillo  ", COLOR_YELLOW, COLOR_RESET);
    printf("%sD%s=Cian  ", COLOR_CYAN, COLOR_RESET);
    printf("·=Vacío");
    printf("%*s", ancho_display - 60, "║\n");
}

// Loop principal de monitoreo
void ejecutar_monitor() {
    clear_screen();
    
    printf("\n");
    print_timestamp("Monitor iniciado\n");
    printf("Presiona Ctrl+C para detener.\n\n");
    
    sleep(1);
    
    int frame = 0;
    
    while (running && banda->activa > 0) {
        clear_screen();
        
        int ancho_display = 80;
        
        // Título principal
        move_cursor(1, 1);
        dibujar_borde_superior(ancho_display);
        
        printf("║");
        printf("%s%s", COLOR_BOLD, COLOR_CYAN);
        printf("              LEGO MASTER - MONITOR DEL SISTEMA              ");
        printf("%s", COLOR_RESET);
        printf("%*s", ancho_display - 62, "║\n");
        
        time_t now = time(NULL);
        struct tm *t = localtime(&now);
        printf("║ [%02d:%02d:%02d] Frame: %d",
               t->tm_hour, t->tm_min, t->tm_sec, frame);
        printf("%*s", ancho_display - 26, "║\n");
        
        dibujar_linea_divisoria(ancho_display);
        
        // Visualizar banda
        visualizar_banda();
        
        // Visualizar estadísticas
        visualizar_estadisticas();
        
        // Leyenda
        visualizar_leyenda();
        
        // Borde inferior
        dibujar_borde_inferior(ancho_display);
        
        printf("\n%sPresiona Ctrl+C para detener%s\n", COLOR_YELLOW, COLOR_RESET);
        
        frame++;
        usleep(200000);  // Actualizar cada 200ms
    }
    
    clear_screen();
    print_timestamp("Monitor finalizado\n");
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;
    
    // Configurar manejador de señales
    signal(SIGINT, cleanup_handler);
    signal(SIGTERM, cleanup_handler);
    
    // Conectar a memoria compartida
    if (conectar_memoria() < 0) {
        fprintf(stderr, "Error: No se pudo conectar a la banda\n");
        fprintf(stderr, "Asegúrate de que el proceso 'banda' esté ejecutándose.\n");
        exit(EXIT_FAILURE);
    }
    
    // Ejecutar monitor
    ejecutar_monitor();
    
    // Cleanup
    if (banda != NULL) shmdt(banda);
    if (stats != NULL) shmdt(stats);
    
    return 0;
}