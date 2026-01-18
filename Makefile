# Makefile para LEGO Master - Sistema de Empaquetado
# Proyecto Final 2025

CC = gcc
CFLAGS = -Wall -Wextra -pthread -std=c11 -D_POSIX_C_SOURCE=200809L -O2
LDFLAGS = -pthread -lrt -lm

# Directorios
SRC_DIR = src
BIN_DIR = bin
SCRIPTS_DIR = scripts

# Archivos
HEADERS = $(SRC_DIR)/common.h
EXECUTABLES = banda dispensadores celda monitor

# Colores para output
CYAN = \033[0;36m
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

# ============================================
#  TARGETS PRINCIPALES
# ============================================

.PHONY: all clean clean-ipc distclean test help

all: setup $(EXECUTABLES)
	@echo ""
	@echo "$(GREEN)✓ Compilación completada$(NC)"
	@echo ""
	@echo "Ejecutables disponibles en $(BIN_DIR)/"
	@echo "  • banda - Banda transportadora"
	@echo "  • dispensadores - Generador de piezas"
	@echo "  • celda - Celda de empaquetado"
	@echo "  • monitor - Visualización (opcional)"
	@echo ""
	@echo "Para ejecutar: $(CYAN)make test$(NC) o $(CYAN)./test_completo.sh$(NC)"
	@echo ""

# Crear directorio bin
setup:
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(SCRIPTS_DIR)

# ============================================
#  COMPILACIÓN DE COMPONENTES
# ============================================

banda: $(SRC_DIR)/banda.c $(HEADERS)
	@echo "$(CYAN)Compilando banda transportadora...$(NC)"
	$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $< $(LDFLAGS)
	@echo "$(GREEN)✓ banda$(NC)"

dispensadores: $(SRC_DIR)/dispensadores.c $(HEADERS)
	@echo "$(CYAN)Compilando dispensadores...$(NC)"
	$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $< $(LDFLAGS)
	@echo "$(GREEN)✓ dispensadores$(NC)"

celda: $(SRC_DIR)/celda.c $(HEADERS)
	@echo "$(CYAN)Compilando celda de empaquetado...$(NC)"
	$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $< $(LDFLAGS)
	@echo "$(GREEN)✓ celda$(NC)"

monitor: $(SRC_DIR)/monitor.c $(HEADERS)
	@echo "$(CYAN)Compilando monitor...$(NC)"
	$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $< $(LDFLAGS)
	@echo "$(GREEN)✓ monitor$(NC)"

# ============================================
#  LIMPIEZA
# ============================================

clean:
	@echo "$(YELLOW)Eliminando ejecutables...$(NC)"
	@rm -rf $(BIN_DIR)
	@echo "$(GREEN)✓ Ejecutables eliminados$(NC)"

clean-ipc:
	@echo "$(YELLOW)Limpiando recursos IPC...$(NC)"
	@-ipcs -m | grep $(shell id -u) | grep 2222 | awk '{print $$2}' | xargs -r -n1 ipcrm -m 2>/dev/null || true
	@-ipcs -m | grep $(shell id -u) | grep 2224 | awk '{print $$2}' | xargs -r -n1 ipcrm -m 2>/dev/null || true
	@-ipcs -s | grep $(shell id -u) | grep 2223 | awk '{print $$2}' | xargs -r -n1 ipcrm -s 2>/dev/null || true
	@-ipcs -s | grep $(shell id -u) | grep 2225 | awk '{print $$2}' | xargs -r -n1 ipcrm -s 2>/dev/null || true
	@-pkill -u $(shell id -u) banda 2>/dev/null || true
	@-pkill -u $(shell id -u) celda 2>/dev/null || true
	@-pkill -u $(shell id -u) dispensadores 2>/dev/null || true
	@-pkill -u $(shell id -u) monitor 2>/dev/null || true
	@echo "$(GREEN)✓ Recursos IPC limpiados$(NC)"

distclean: clean clean-ipc
	@echo "$(GREEN)✓ Limpieza completa realizada$(NC)"

# ============================================
#  PRUEBAS
# ============================================

test: all clean-ipc
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)  Iniciando prueba del sistema$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ -f test_completo.sh ]; then \
		chmod +x test_completo.sh; \
		./test_completo.sh; \
	else \
		echo "$(RED)Error: test_completo.sh no encontrado$(NC)"; \
		exit 1; \
	fi

# Prueba rápida (menos sets)
test-quick: all clean-ipc
	@echo "$(CYAN)Prueba rápida (2 sets)...$(NC)"
	@./bin/banda 50 200 > /tmp/banda.log 2>&1 &
	@sleep 2
	@./bin/celda 1 15 3 2 4 1 > /tmp/celda1.log 2>&1 &
	@sleep 2
	@./bin/dispensadores 4 2 3 2 4 1 150000
	@sleep 10
	@$(MAKE) clean-ipc
	@echo "$(GREEN)✓ Prueba rápida completada$(NC)"
	@echo "Ver logs en /tmp/celda1.log"

# Verificar estado de IPC
check-ipc:
	@echo "$(CYAN)Estado de recursos IPC:$(NC)"
	@echo ""
	@echo "$(YELLOW)Memoria compartida:$(NC)"
	@ipcs -m | grep $(shell id -u) || echo "  (Ninguno)"
	@echo ""
	@echo "$(YELLOW)Semáforos:$(NC)"
	@ipcs -s | grep $(shell id -u) || echo "  (Ninguno)"
	@echo ""
	@echo "$(YELLOW)Procesos activos:$(NC)"
	@ps aux | grep -E "(banda|celda|dispensadores|monitor)" | grep -v grep || echo "  (Ninguno)"

# ============================================
#  DOCUMENTACIÓN Y AYUDA
# ============================================

help:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)  LEGO Master - Sistema de Empaquetado$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Compilación:$(NC)"
	@echo "  make all           - Compilar todos los componentes"
	@echo "  make banda         - Compilar solo banda"
	@echo "  make celda         - Compilar solo celda"
	@echo "  make dispensadores - Compilar solo dispensadores"
	@echo "  make monitor       - Compilar solo monitor"
	@echo ""
	@echo "$(YELLOW)Limpieza:$(NC)"
	@echo "  make clean         - Eliminar ejecutables"
	@echo "  make clean-ipc     - Limpiar recursos IPC y procesos"
	@echo "  make distclean     - Limpieza completa"
	@echo ""
	@echo "$(YELLOW)Pruebas:$(NC)"
	@echo "  make test          - Prueba completa del sistema"
	@echo "  make test-quick    - Prueba rápida (2 sets)"
	@echo "  make check-ipc     - Ver estado de recursos IPC"
	@echo ""
	@echo "$(YELLOW)Ejecución manual:$(NC)"
	@echo "  ./bin/banda <tamaño> <velocidad_ms>"
	@echo "  ./bin/celda <id> <pos> <A> <B> <C> <D>"
	@echo "  ./bin/dispensadores <#disp> <#sets> <A> <B> <C> <D> <intervalo>"
	@echo "  ./bin/monitor"
	@echo ""
	@echo "$(YELLOW)Ejemplo completo:$(NC)"
	@echo "  Terminal 1: ./bin/banda 60 200 &"
	@echo "  Terminal 2: ./bin/celda 1 15 3 2 4 1 &"
	@echo "  Terminal 3: ./bin/celda 2 40 3 2 4 1 &"
	@echo "  Terminal 4: ./bin/dispensadores 6 5 3 2 4 1 100000"
	@echo ""
	@echo "$(YELLOW)Documentación:$(NC)"
	@echo "  README.md - Descripción general"
	@echo "  DISEÑO.md - Documento de diseño detallado"
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"

# ============================================
#  DESARROLLO
# ============================================

# Verificar código (requiere cppcheck)
check:
	@if command -v cppcheck >/dev/null 2>&1; then \
		echo "$(CYAN)Analizando código...$(NC)"; \
		cppcheck --enable=all --suppress=missingIncludeSystem $(SRC_DIR)/*.c; \
		echo "$(GREEN)✓ Análisis completado$(NC)"; \
	else \
		echo "$(YELLOW)cppcheck no instalado, saltando análisis$(NC)"; \
	fi

# Recompilar todo desde cero
rebuild: distclean all
	@echo "$(GREEN)✓ Reconstrucción completa$(NC)"

.DEFAULT_GOAL := help