# Makefile para LEGO Master - Sistema de Empaquetado
# Proyecto Final 2025
# Autor: Luis Vergara Arellano

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
MAGENTA = \033[0;35m
BOLD = \033[1m
NC = \033[0m # No Color

# ============================================
#  TARGETS PRINCIPALES
# ============================================

.PHONY: all clean clean-ipc distclean test test-quick test-validacion help setup-scripts

all: setup $(EXECUTABLES)
	@echo ""
	@echo "$(GREEN)$(BOLD)✓ Compilación completada$(NC)"
	@echo ""
	@echo "$(CYAN)Ejecutables disponibles en $(BIN_DIR)/$(NC)"
	@echo "  • banda         - Banda transportadora circular"
	@echo "  • dispensadores - Generador de piezas aleatorio"
	@echo "  • celda         - Celda de empaquetado (4 brazos)"
	@echo "  • monitor       - Visualización en tiempo real"
	@echo ""
	@echo "$(CYAN)$(BOLD)Para demostración al profesor:$(NC)"
	@echo "  $(GREEN)make test-rapido$(NC)      - Demo express (5 min)"
	@echo "  $(GREEN)make test-validacion$(NC)  - Validación completa (8 min)"
	@echo ""
	@echo "$(CYAN)Otros comandos útiles:$(NC)"
	@echo "  make test        - Prueba completa del sistema"
	@echo "  make help        - Ver todos los comandos disponibles"
	@echo ""

# Crear directorios necesarios
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
#  DEMOSTRACIONES Y PRUEBAS
# ============================================

# Demostración rápida para el profesor (5 minutos)
test-rapido: all clean-ipc setup-scripts
	@echo ""
	@echo "$(MAGENTA)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)$(BOLD)  DEMOSTRACIÓN RÁPIDA (5 minutos)$(NC)"
	@echo "$(MAGENTA)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ -f $(SCRIPTS_DIR)/test_rapido.sh ]; then \
		chmod +x $(SCRIPTS_DIR)/test_rapido.sh; \
		$(SCRIPTS_DIR)/test_rapido.sh; \
	else \
		echo "$(RED)Error: scripts/test_rapido.sh no encontrado$(NC)"; \
		echo "$(YELLOW)Crea el script según INSTRUCCIONES.txt$(NC)"; \
		exit 1; \
	fi

# Validación completa de requisitos del PDF (8 minutos)
test-validacion: all clean-ipc setup-scripts
	@echo ""
	@echo "$(MAGENTA)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)$(BOLD)  VALIDACIÓN COMPLETA DE REQUISITOS PDF (8 minutos)$(NC)"
	@echo "$(MAGENTA)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ -f $(SCRIPTS_DIR)/test_validacion_pdf.sh ]; then \
		chmod +x $(SCRIPTS_DIR)/test_validacion_pdf.sh; \
		$(SCRIPTS_DIR)/test_validacion_pdf.sh; \
	else \
		echo "$(RED)Error: scripts/test_validacion_pdf.sh no encontrado$(NC)"; \
		echo "$(YELLOW)Crea el script según INSTRUCCIONES.txt$(NC)"; \
		exit 1; \
	fi

# Prueba completa del sistema (original)
test: all clean-ipc
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)  Iniciando prueba del sistema$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ -f test_completo.sh ]; then \
		chmod +x test_completo.sh; \
		./test_completo.sh; \
	elif [ -f $(SCRIPTS_DIR)/test_completo.sh ]; then \
		chmod +x $(SCRIPTS_DIR)/test_completo.sh; \
		$(SCRIPTS_DIR)/test_completo.sh; \
	else \
		echo "$(YELLOW)Advertencia: test_completo.sh no encontrado$(NC)"; \
		echo "$(YELLOW)Usa 'make test-rapido' o 'make test-validacion'$(NC)"; \
	fi

# Prueba rápida (menos sets) - Alias para test-rapido
test-quick: test-rapido

# Dar permisos de ejecución a los scripts
setup-scripts:
	@if [ -d $(SCRIPTS_DIR) ]; then \
		chmod +x $(SCRIPTS_DIR)/*.sh 2>/dev/null || true; \
	fi

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

clean-logs:
	@echo "$(YELLOW)Limpiando logs...$(NC)"
	@rm -f /tmp/lego_*.log /tmp/demo_*.log /tmp/valid_*.log /tmp/rapido_*.log 2>/dev/null || true
	@rm -f /tmp/*_celda*.log /tmp/*_banda.log /tmp/*_disp.log 2>/dev/null || true
	@echo "$(GREEN)✓ Logs eliminados$(NC)"

distclean: clean clean-ipc clean-logs
	@echo "$(GREEN)✓ Limpieza completa realizada$(NC)"

# ============================================
#  VERIFICACIÓN Y DIAGNÓSTICO
# ============================================

# Verificar estado de IPC
check-ipc:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  Estado de Recursos IPC$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Memoria compartida:$(NC)"
	@ipcs -m | head -3
	@ipcs -m | grep $(shell id -u) || echo "  $(GREEN)(Ninguno)$(NC)"
	@echo ""
	@echo "$(YELLOW)Semáforos:$(NC)"
	@ipcs -s | head -3
	@ipcs -s | grep $(shell id -u) || echo "  $(GREEN)(Ninguno)$(NC)"
	@echo ""
	@echo "$(YELLOW)Procesos activos:$(NC)"
	@ps aux | head -1
	@ps aux | grep -E "(banda|celda|dispensadores|monitor)" | grep -v grep || echo "  $(GREEN)(Ninguno)$(NC)"
	@echo ""

# Verificar logs generados
check-logs:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  Logs Disponibles$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@ls -lh /tmp/*celda*.log /tmp/*banda*.log /tmp/*disp*.log 2>/dev/null || echo "  $(YELLOW)No hay logs disponibles$(NC)"
	@echo ""

# Verificar balance en logs
check-balance:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  Suspensiones por Balance Detectadas$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if ls /tmp/*celda*.log >/dev/null 2>&1; then \
		grep "💤 Suspendido" /tmp/*celda*.log 2>/dev/null || echo "  $(YELLOW)No se detectaron suspensiones$(NC)"; \
		echo ""; \
		TOTAL=$$(grep -c "💤 Suspendido" /tmp/*celda*.log 2>/dev/null || echo 0); \
		echo "  $(GREEN)Total de suspensiones: $$TOTAL$(NC)"; \
	else \
		echo "  $(YELLOW)No hay logs disponibles$(NC)"; \
		echo "  $(YELLOW)Ejecuta primero: make test-rapido$(NC)"; \
	fi
	@echo ""

# Verificar requisitos del sistema
check-system:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  Verificación del Sistema$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Compilador:$(NC)"
	@which gcc > /dev/null && echo "  $(GREEN)✓ GCC disponible: $$(gcc --version | head -1)$(NC)" || echo "  $(RED)✗ GCC no encontrado$(NC)"
	@echo ""
	@echo "$(YELLOW)Herramientas:$(NC)"
	@which make > /dev/null && echo "  $(GREEN)✓ Make disponible$(NC)" || echo "  $(RED)✗ Make no encontrado$(NC)"
	@which ipcs > /dev/null && echo "  $(GREEN)✓ IPC tools disponibles$(NC)" || echo "  $(RED)✗ IPC tools no encontradas$(NC)"
	@echo ""
	@echo "$(YELLOW)Ejecutables:$(NC)"
	@[ -f $(BIN_DIR)/banda ] && echo "  $(GREEN)✓ banda$(NC)" || echo "  $(YELLOW)✗ banda (ejecuta 'make all')$(NC)"
	@[ -f $(BIN_DIR)/celda ] && echo "  $(GREEN)✓ celda$(NC)" || echo "  $(YELLOW)✗ celda (ejecuta 'make all')$(NC)"
	@[ -f $(BIN_DIR)/dispensadores ] && echo "  $(GREEN)✓ dispensadores$(NC)" || echo "  $(YELLOW)✗ dispensadores (ejecuta 'make all')$(NC)"
	@[ -f $(BIN_DIR)/monitor ] && echo "  $(GREEN)✓ monitor$(NC)" || echo "  $(YELLOW)✗ monitor (ejecuta 'make all')$(NC)"
	@echo ""
	@echo "$(YELLOW)Scripts de demostración:$(NC)"
	@[ -f $(SCRIPTS_DIR)/test_rapido.sh ] && echo "  $(GREEN)✓ test_rapido.sh$(NC)" || echo "  $(YELLOW)✗ test_rapido.sh (ver INSTRUCCIONES.txt)$(NC)"
	@[ -f $(SCRIPTS_DIR)/test_validacion_pdf.sh ] && echo "  $(GREEN)✓ test_validacion_pdf.sh$(NC)" || echo "  $(YELLOW)✗ test_validacion_pdf.sh (ver INSTRUCCIONES.txt)$(NC)"
	@echo ""

# ============================================
#  AYUDA Y DOCUMENTACIÓN
# ============================================

help:
	@echo "$(CYAN)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  LEGO Master - Sistema de Empaquetado$(NC)"
	@echo "$(CYAN)$(BOLD)  Proyecto Final - Sistemas Operativos 2025$(NC)"
	@echo "$(CYAN)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(MAGENTA)$(BOLD)PARA EL PROFESOR (DEMOSTRACIONES):$(NC)"
	@echo "  $(GREEN)make test-rapido$(NC)        - Demo express (5 min) - ⭐ RECOMENDADO"
	@echo "  $(GREEN)make test-validacion$(NC)    - Validación completa de PDF (8 min)"
	@echo ""
	@echo "$(YELLOW)$(BOLD)COMPILACIÓN:$(NC)"
	@echo "  make all              - Compilar todos los componentes"
	@echo "  make banda            - Compilar solo banda"
	@echo "  make celda            - Compilar solo celda"
	@echo "  make dispensadores    - Compilar solo dispensadores"
	@echo "  make monitor          - Compilar solo monitor"
	@echo ""
	@echo "$(YELLOW)$(BOLD)LIMPIEZA:$(NC)"
	@echo "  make clean            - Eliminar ejecutables"
	@echo "  make clean-ipc        - Limpiar recursos IPC y procesos"
	@echo "  make clean-logs       - Eliminar archivos de log"
	@echo "  make distclean        - Limpieza completa (todo lo anterior)"
	@echo ""
	@echo "$(YELLOW)$(BOLD)PRUEBAS:$(NC)"
	@echo "  make test             - Prueba completa del sistema"
	@echo "  make test-quick       - Alias para test-rapido"
	@echo ""
	@echo "$(YELLOW)$(BOLD)VERIFICACIÓN:$(NC)"
	@echo "  make check-system     - Verificar requisitos del sistema"
	@echo "  make check-ipc        - Ver estado de recursos IPC"
	@echo "  make check-logs       - Listar logs disponibles"
	@echo "  make check-balance    - Ver suspensiones por balance"
	@echo ""
	@echo "$(YELLOW)$(BOLD)EJECUCIÓN MANUAL:$(NC)"
	@echo "  ./bin/banda <tamaño> <velocidad_ms>"
	@echo "  ./bin/celda <id> <pos> <A> <B> <C> <D>"
	@echo "  ./bin/dispensadores <#disp> <#sets> <A> <B> <C> <D> <intervalo>"
	@echo "  ./bin/monitor"
	@echo ""
	@echo "$(YELLOW)$(BOLD)EJEMPLO COMPLETO:$(NC)"
	@echo "  Terminal 1: ./bin/banda 60 200 &"
	@echo "  Terminal 2: ./bin/celda 1 15 3 2 4 1 &"
	@echo "  Terminal 3: ./bin/celda 2 40 3 2 4 1 &"
	@echo "  Terminal 4: ./bin/dispensadores 6 5 3 2 4 1 100000"
	@echo ""
	@echo "$(YELLOW)$(BOLD)DOCUMENTACIÓN:$(NC)"
	@echo "  README.md             - Descripción general del proyecto"
	@echo "  DISEÑO.md             - Documento de diseño detallado"
	@echo "  GUIA_PROFESOR.md      - Guía de evaluación para el profesor"
	@echo "  INSTRUCCIONES.txt     - Instrucciones de instalación de scripts"
	@echo ""
	@echo "$(CYAN)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)Más información: $(BOLD)README.md$(NC) $(CYAN)o$(NC) $(BOLD)GUIA_PROFESOR.md$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""

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

# Crear documentación (requiere doxygen)
docs:
	@if command -v doxygen >/dev/null 2>&1; then \
		echo "$(CYAN)Generando documentación...$(NC)"; \
		doxygen Doxyfile 2>/dev/null || echo "$(YELLOW)Crear Doxyfile primero$(NC)"; \
	else \
		echo "$(YELLOW)doxygen no instalado$(NC)"; \
	fi

.DEFAULT_GOAL := all# Makefile para LEGO Master - Sistema de Empaquetado
# Proyecto Final 2025
# Autor: Luis Vergara Arellano

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
MAGENTA = \033[0;35m
BOLD = \033[1m
NC = \033[0m # No Color

# ============================================
#  TARGETS PRINCIPALES
# ============================================

.PHONY: all clean clean-ipc distclean test test-quick test-validacion help setup-scripts

all: setup $(EXECUTABLES)
	@echo ""
	@echo "$(GREEN)$(BOLD)✓ Compilación completada$(NC)"
	@echo ""
	@echo "$(CYAN)Ejecutables disponibles en $(BIN_DIR)/$(NC)"
	@echo "  • banda         - Banda transportadora circular"
	@echo "  • dispensadores - Generador de piezas aleatorio"
	@echo "  • celda         - Celda de empaquetado (4 brazos)"
	@echo "  • monitor       - Visualización en tiempo real"
	@echo ""
	@echo "$(CYAN)$(BOLD)Para demostración al profesor:$(NC)"
	@echo "  $(GREEN)make test-rapido$(NC)      - Demo express (5 min)"
	@echo "  $(GREEN)make test-validacion$(NC)  - Validación completa (8 min)"
	@echo ""
	@echo "$(CYAN)Otros comandos útiles:$(NC)"
	@echo "  make test        - Prueba completa del sistema"
	@echo "  make help        - Ver todos los comandos disponibles"
	@echo ""

# Crear directorios necesarios
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
#  DEMOSTRACIONES Y PRUEBAS
# ============================================

# Demostración rápida para el profesor (5 minutos)
test-rapido: all clean-ipc setup-scripts
	@echo ""
	@echo "$(MAGENTA)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)$(BOLD)  DEMOSTRACIÓN RÁPIDA (5 minutos)$(NC)"
	@echo "$(MAGENTA)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ -f $(SCRIPTS_DIR)/test_rapido.sh ]; then \
		chmod +x $(SCRIPTS_DIR)/test_rapido.sh; \
		$(SCRIPTS_DIR)/test_rapido.sh; \
	else \
		echo "$(RED)Error: scripts/test_rapido.sh no encontrado$(NC)"; \
		echo "$(YELLOW)Crea el script según INSTRUCCIONES.txt$(NC)"; \
		exit 1; \
	fi

# Validación completa de requisitos del PDF (8 minutos)
test-validacion: all clean-ipc setup-scripts
	@echo ""
	@echo "$(MAGENTA)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)$(BOLD)  VALIDACIÓN COMPLETA DE REQUISITOS PDF (8 minutos)$(NC)"
	@echo "$(MAGENTA)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ -f $(SCRIPTS_DIR)/test_validacion_pdf.sh ]; then \
		chmod +x $(SCRIPTS_DIR)/test_validacion_pdf.sh; \
		$(SCRIPTS_DIR)/test_validacion_pdf.sh; \
	else \
		echo "$(RED)Error: scripts/test_validacion_pdf.sh no encontrado$(NC)"; \
		echo "$(YELLOW)Crea el script según INSTRUCCIONES.txt$(NC)"; \
		exit 1; \
	fi

# Prueba completa del sistema (original)
test: all clean-ipc
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)  Iniciando prueba del sistema$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ -f test_completo.sh ]; then \
		chmod +x test_completo.sh; \
		./test_completo.sh; \
	elif [ -f $(SCRIPTS_DIR)/test_completo.sh ]; then \
		chmod +x $(SCRIPTS_DIR)/test_completo.sh; \
		$(SCRIPTS_DIR)/test_completo.sh; \
	else \
		echo "$(YELLOW)Advertencia: test_completo.sh no encontrado$(NC)"; \
		echo "$(YELLOW)Usa 'make test-rapido' o 'make test-validacion'$(NC)"; \
	fi

# Prueba rápida (menos sets) - Alias para test-rapido
test-quick: test-rapido

# Dar permisos de ejecución a los scripts
setup-scripts:
	@if [ -d $(SCRIPTS_DIR) ]; then \
		chmod +x $(SCRIPTS_DIR)/*.sh 2>/dev/null || true; \
	fi

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

clean-logs:
	@echo "$(YELLOW)Limpiando logs...$(NC)"
	@rm -f /tmp/lego_*.log /tmp/demo_*.log /tmp/valid_*.log /tmp/rapido_*.log 2>/dev/null || true
	@rm -f /tmp/*_celda*.log /tmp/*_banda.log /tmp/*_disp.log 2>/dev/null || true
	@echo "$(GREEN)✓ Logs eliminados$(NC)"

distclean: clean clean-ipc clean-logs
	@echo "$(GREEN)✓ Limpieza completa realizada$(NC)"

# ============================================
#  VERIFICACIÓN Y DIAGNÓSTICO
# ============================================

# Verificar estado de IPC
check-ipc:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  Estado de Recursos IPC$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Memoria compartida:$(NC)"
	@ipcs -m | head -3
	@ipcs -m | grep $(shell id -u) || echo "  $(GREEN)(Ninguno)$(NC)"
	@echo ""
	@echo "$(YELLOW)Semáforos:$(NC)"
	@ipcs -s | head -3
	@ipcs -s | grep $(shell id -u) || echo "  $(GREEN)(Ninguno)$(NC)"
	@echo ""
	@echo "$(YELLOW)Procesos activos:$(NC)"
	@ps aux | head -1
	@ps aux | grep -E "(banda|celda|dispensadores|monitor)" | grep -v grep || echo "  $(GREEN)(Ninguno)$(NC)"
	@echo ""

# Verificar logs generados
check-logs:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  Logs Disponibles$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@ls -lh /tmp/*celda*.log /tmp/*banda*.log /tmp/*disp*.log 2>/dev/null || echo "  $(YELLOW)No hay logs disponibles$(NC)"
	@echo ""

# Verificar balance en logs
check-balance:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  Suspensiones por Balance Detectadas$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if ls /tmp/*celda*.log >/dev/null 2>&1; then \
		grep "💤 Suspendido" /tmp/*celda*.log 2>/dev/null || echo "  $(YELLOW)No se detectaron suspensiones$(NC)"; \
		echo ""; \
		TOTAL=$$(grep -c "💤 Suspendido" /tmp/*celda*.log 2>/dev/null || echo 0); \
		echo "  $(GREEN)Total de suspensiones: $$TOTAL$(NC)"; \
	else \
		echo "  $(YELLOW)No hay logs disponibles$(NC)"; \
		echo "  $(YELLOW)Ejecuta primero: make test-rapido$(NC)"; \
	fi
	@echo ""

# Verificar requisitos del sistema
check-system:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  Verificación del Sistema$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Compilador:$(NC)"
	@which gcc > /dev/null && echo "  $(GREEN)✓ GCC disponible: $$(gcc --version | head -1)$(NC)" || echo "  $(RED)✗ GCC no encontrado$(NC)"
	@echo ""
	@echo "$(YELLOW)Herramientas:$(NC)"
	@which make > /dev/null && echo "  $(GREEN)✓ Make disponible$(NC)" || echo "  $(RED)✗ Make no encontrado$(NC)"
	@which ipcs > /dev/null && echo "  $(GREEN)✓ IPC tools disponibles$(NC)" || echo "  $(RED)✗ IPC tools no encontradas$(NC)"
	@echo ""
	@echo "$(YELLOW)Ejecutables:$(NC)"
	@[ -f $(BIN_DIR)/banda ] && echo "  $(GREEN)✓ banda$(NC)" || echo "  $(YELLOW)✗ banda (ejecuta 'make all')$(NC)"
	@[ -f $(BIN_DIR)/celda ] && echo "  $(GREEN)✓ celda$(NC)" || echo "  $(YELLOW)✗ celda (ejecuta 'make all')$(NC)"
	@[ -f $(BIN_DIR)/dispensadores ] && echo "  $(GREEN)✓ dispensadores$(NC)" || echo "  $(YELLOW)✗ dispensadores (ejecuta 'make all')$(NC)"
	@[ -f $(BIN_DIR)/monitor ] && echo "  $(GREEN)✓ monitor$(NC)" || echo "  $(YELLOW)✗ monitor (ejecuta 'make all')$(NC)"
	@echo ""
	@echo "$(YELLOW)Scripts de demostración:$(NC)"
	@[ -f $(SCRIPTS_DIR)/test_rapido.sh ] && echo "  $(GREEN)✓ test_rapido.sh$(NC)" || echo "  $(YELLOW)✗ test_rapido.sh (ver INSTRUCCIONES.txt)$(NC)"
	@[ -f $(SCRIPTS_DIR)/test_validacion_pdf.sh ] && echo "  $(GREEN)✓ test_validacion_pdf.sh$(NC)" || echo "  $(YELLOW)✗ test_validacion_pdf.sh (ver INSTRUCCIONES.txt)$(NC)"
	@echo ""

# ============================================
#  AYUDA Y DOCUMENTACIÓN
# ============================================

help:
	@echo "$(CYAN)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)$(BOLD)  LEGO Master - Sistema de Empaquetado$(NC)"
	@echo "$(CYAN)$(BOLD)  Proyecto Final - Sistemas Operativos 2025$(NC)"
	@echo "$(CYAN)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(MAGENTA)$(BOLD)PARA EL PROFESOR (DEMOSTRACIONES):$(NC)"
	@echo "  $(GREEN)make test-rapido$(NC)        - Demo express (5 min) - ⭐ RECOMENDADO"
	@echo "  $(GREEN)make test-validacion$(NC)    - Validación completa de PDF (8 min)"
	@echo ""
	@echo "$(YELLOW)$(BOLD)COMPILACIÓN:$(NC)"
	@echo "  make all              - Compilar todos los componentes"
	@echo "  make banda            - Compilar solo banda"
	@echo "  make celda            - Compilar solo celda"
	@echo "  make dispensadores    - Compilar solo dispensadores"
	@echo "  make monitor          - Compilar solo monitor"
	@echo ""
	@echo "$(YELLOW)$(BOLD)LIMPIEZA:$(NC)"
	@echo "  make clean            - Eliminar ejecutables"
	@echo "  make clean-ipc        - Limpiar recursos IPC y procesos"
	@echo "  make clean-logs       - Eliminar archivos de log"
	@echo "  make distclean        - Limpieza completa (todo lo anterior)"
	@echo ""
	@echo "$(YELLOW)$(BOLD)PRUEBAS:$(NC)"
	@echo "  make test             - Prueba completa del sistema"
	@echo "  make test-quick       - Alias para test-rapido"
	@echo ""
	@echo "$(YELLOW)$(BOLD)VERIFICACIÓN:$(NC)"
	@echo "  make check-system     - Verificar requisitos del sistema"
	@echo "  make check-ipc        - Ver estado de recursos IPC"
	@echo "  make check-logs       - Listar logs disponibles"
	@echo "  make check-balance    - Ver suspensiones por balance"
	@echo ""
	@echo "$(YELLOW)$(BOLD)EJECUCIÓN MANUAL:$(NC)"
	@echo "  ./bin/banda <tamaño> <velocidad_ms>"
	@echo "  ./bin/celda <id> <pos> <A> <B> <C> <D>"
	@echo "  ./bin/dispensadores <#disp> <#sets> <A> <B> <C> <D> <intervalo>"
	@echo "  ./bin/monitor"
	@echo ""
	@echo "$(YELLOW)$(BOLD)EJEMPLO COMPLETO:$(NC)"
	@echo "  Terminal 1: ./bin/banda 60 200 &"
	@echo "  Terminal 2: ./bin/celda 1 15 3 2 4 1 &"
	@echo "  Terminal 3: ./bin/celda 2 40 3 2 4 1 &"
	@echo "  Terminal 4: ./bin/dispensadores 6 5 3 2 4 1 100000"
	@echo ""
	@echo "$(YELLOW)$(BOLD)DOCUMENTACIÓN:$(NC)"
	@echo "  README.md             - Descripción general del proyecto"
	@echo "  DISEÑO.md             - Documento de diseño detallado"
	@echo "  GUIA_PROFESOR.md      - Guía de evaluación para el profesor"
	@echo "  INSTRUCCIONES.txt     - Instrucciones de instalación de scripts"
	@echo ""
	@echo "$(CYAN)$(BOLD)════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)Más información: $(BOLD)README.md$(NC) $(CYAN)o$(NC) $(BOLD)GUIA_PROFESOR.md$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""

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

# Crear documentación (requiere doxygen)
docs:
	@if command -v doxygen >/dev/null 2>&1; then \
		echo "$(CYAN)Generando documentación...$(NC)"; \
		doxygen Doxyfile 2>/dev/null || echo "$(YELLOW)Crear Doxyfile primero$(NC)"; \
	else \
		echo "$(YELLOW)doxygen no instalado$(NC)"; \
	fi

.DEFAULT_GOAL := all