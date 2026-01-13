# Makefile para LEGO Master - Sistema de Empaquetado
# Proyecto 2T Final 2025

CC = gcc
CFLAGS = -Wall -Wextra -pthread -std=c11 -D_POSIX_C_SOURCE=200809L
LDFLAGS = -pthread -lrt -lm

# Directorios
SRC_DIR = src
BIN_DIR = bin
SCRIPTS_DIR = scripts

# Archivos fuente
SOURCES = $(wildcard $(SRC_DIR)/*.c)
HEADERS = $(SRC_DIR)/common.h

# Ejecutables
EXECUTABLES = banda dispensadores celda monitor

# Targets principales
.PHONY: all clean help setup test

all: setup $(EXECUTABLES)

# Crear directorio bin si no existe
setup:
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(SCRIPTS_DIR)
	@echo "Directorios creados: $(BIN_DIR), $(SCRIPTS_DIR)"

# Compilar banda transportadora
banda: $(SRC_DIR)/banda.c $(HEADERS)
	$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $< $(LDFLAGS)
	@echo "✓ Compilado: banda"

# Compilar dispensadores (Día 2)
dispensadores:
	@if [ -f $(SRC_DIR)/dispensadores.c ]; then \
		$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $(SRC_DIR)/dispensadores.c $(LDFLAGS); \
		echo "✓ Compilado: dispensadores"; \
	else \
		echo "⚠ dispensadores.c no existe aún (Día 2)"; \
	fi

# Compilar celda de empaquetado (Día 3)
celda:
	@if [ -f $(SRC_DIR)/celda.c ]; then \
		$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $(SRC_DIR)/celda.c $(LDFLAGS); \
		echo "✓ Compilado: celda"; \
	else \
		echo "⚠ celda.c no existe aún (Día 3)"; \
	fi

# Compilar monitor (Día 2)
monitor:
	@if [ -f $(SRC_DIR)/monitor.c ]; then \
		$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $(SRC_DIR)/monitor.c $(LDFLAGS); \
		echo "✓ Compilado: monitor"; \
	else \
		echo "⚠ monitor.c no existe aún (Día 2)"; \
	fi

# Limpiar ejecutables
clean:
	@rm -rf $(BIN_DIR)
	@echo "✓ Ejecutables eliminados"

# Limpiar recursos IPC
clean-ipc:
	@echo "Limpiando recursos IPC..."
	@-ipcs -m | grep $(shell id -u) | grep 2222 | awk '{print $$2}' | xargs -r -n1 ipcrm -m 2>/dev/null || true
	@-ipcs -m | grep $(shell id -u) | grep 2224 | awk '{print $$2}' | xargs -r -n1 ipcrm -m 2>/dev/null || true
	@-ipcs -s | grep $(shell id -u) | grep 2223 | awk '{print $$2}' | xargs -r -n1 ipcrm -s 2>/dev/null || true
	@-ipcs -s | grep $(shell id -u) | grep 2225 | awk '{print $$2}' | xargs -r -n1 ipcrm -s 2>/dev/null || true
	@echo "✓ Recursos IPC limpiados"

# Limpieza completa
distclean: clean clean-ipc
	@echo "✓ Limpieza completa realizada"

# Prueba básica del Día 1
test-dia1: banda
	@echo "=== Prueba Día 1: Banda Transportadora ==="
	@echo "Iniciando banda de 30 pasos a 200ms..."
	@echo "Presiona Ctrl+C para detener"
	@$(BIN_DIR)/banda 30 200

# Información de uso
help:
	@echo "════════════════════════════════════════════════════════"
	@echo "  LEGO Master - Sistema de Empaquetado"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	@echo "Comandos disponibles:"
	@echo "  make all         - Compilar todos los componentes"
	@echo "  make banda       - Compilar solo banda transportadora"
	@echo "  make clean       - Eliminar ejecutables"
	@echo "  make clean-ipc   - Limpiar recursos IPC (memoria/semáforos)"
	@echo "  make distclean   - Limpieza completa"
	@echo "  make test-dia1   - Prueba básica del Día 1"
	@echo "  make help        - Mostrar esta ayuda"
	@echo ""
	@echo "Ejecución manual:"
	@echo "  ./bin/banda <tamaño> <velocidad_ms>"
	@echo "  Ejemplo: ./bin/banda 50 100"
	@echo ""
	@echo "Estado del proyecto:"
	@echo "  ✓ Día 1: Banda transportadora base"
	@echo "  ⚠ Día 2: Dispensadores (pendiente)"
	@echo "  ⚠ Día 3: Celdas de empaquetado (pendiente)"
	@echo "  ⚠ Día 4: Balance y validación (pendiente)"
	@echo "  ⚠ Día 5: Robustez y celdas dinámicas (pendiente)"
	@echo ""
	@echo "════════════════════════════════════════════════════════"