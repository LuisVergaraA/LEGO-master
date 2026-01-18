#!/bin/bash
# test_simple.sh - Prueba simple y visual del sistema

clear
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     LEGO MASTER - Prueba Simple                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Limpiar IPC
echo "1. Limpiando recursos IPC previos..."
make clean-ipc > /dev/null 2>&1
echo "   ✓ Limpio"
echo ""

# Configuración simple
echo "2. Configuración:"
echo "   - Banda: 50 pasos, 200ms"
echo "   - Dispensadores: 4 unidades, 2 sets"
echo "   - Celda: 1 en posición 15"
echo "   - Total piezas: 20 (2 sets × 10 piezas)"
echo ""

read -p "Presiona Enter para continuar..."
clear

echo "════════════════════════════════════════════════════════"
echo "  INICIANDO SISTEMA (orden correcto)"
echo "════════════════════════════════════════════════════════"
echo ""

# Paso 1: Banda
echo "[1/3] Banda transportadora..."
./bin/banda 50 200 &
BANDA_PID=$!
sleep 2

if ! ps -p $BANDA_PID > /dev/null 2>&1; then
    echo "      ❌ ERROR: Banda no inició"
    exit 1
fi
echo "      ✓ Banda OK (PID: $BANDA_PID)"

# Paso 2: Dispensadores (ANTES de celdas para crear estadísticas)
echo "[2/3] Dispensadores..."
./bin/dispensadores 4 2 3 2 4 1 150000 &
DISP_PID=$!
sleep 2

if ! ps -p $DISP_PID > /dev/null 2>&1; then
    echo "      ❌ ERROR: Dispensadores no iniciaron"
    kill $BANDA_PID 2>/dev/null
    exit 1
fi
echo "      ✓ Dispensadores OK (PID: $DISP_PID)"

# Paso 3: Celda (DESPUÉS de dispensadores)
echo "[3/3] Celda de empaquetado..."
./bin/celda 1 15 3 2 4 1 &
CELDA_PID=$!
sleep 2

if ! ps -p $CELDA_PID > /dev/null 2>&1; then
    echo "      ❌ ERROR: Celda no inició"
    echo ""
    echo "Posibles causas:"
    echo "  - Falta compilar: make all"
    echo "  - Error en código"
    echo ""
    kill $DISP_PID $BANDA_PID 2>/dev/null
    exit 1
fi
echo "      ✓ Celda OK (PID: $CELDA_PID)"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✓ SISTEMA ACTIVO"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Procesos corriendo:"
echo "  Banda:         $BANDA_PID"
echo "  Dispensadores: $DISP_PID"
echo "  Celda:         $CELDA_PID"
echo ""
echo "Observa el output arriba para:"
echo "  → Piezas dispensadas (Ciclos)"
echo "  → Brazos capturando piezas"
echo "  → Mensajes de balance (💤)"
echo "  → Validación de cajas (✅ OK)"
echo ""
echo "Esperando a que termine el dispensado..."
echo "(Aproximadamente 1 minuto para 2 sets)"
echo ""

# Esperar dispensadores
wait $DISP_PID 2>/dev/null

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Dispensado completado"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Esperando 10 segundos para procesamiento final..."
sleep 10

# Detener sistema
echo ""
echo "Deteniendo sistema..."

kill -INT $CELDA_PID 2>/dev/null
sleep 2

kill -INT $BANDA_PID 2>/dev/null
sleep 1

# Limpiar
make clean-ipc > /dev/null 2>&1

echo ""
echo "════════════════════════════════════════════════════════"
echo "  PRUEBA COMPLETADA"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Busca en el output arriba:"
echo ""
echo "✅ ÉXITO si ves:"
echo "   - '[OPERADOR] ✅ OK' (al menos 1 caja)"
echo "   - '[BRAZO N] 💤 Suspendido por balance'"
echo "   - 'RESUMEN FINAL' con estadísticas"
echo ""
echo "❌ PROBLEMA si ves:"
echo "   - 'Cajas completadas OK: 0'"
echo "   - Muchas piezas al tacho"
echo "   - Sin mensajes de balance"
echo ""
echo "Para prueba completa: ./test_completo.sh"
echo ""