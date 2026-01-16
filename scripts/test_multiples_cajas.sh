#!/bin/bash
# test_multiples_cajas.sh - Prueba con múltiples cajas/sets

echo "════════════════════════════════════════════════════════"
echo "  Prueba con Múltiples Cajas - Día 3"
echo "════════════════════════════════════════════════════════"
echo ""

# Limpiar IPC
make clean-ipc > /dev/null 2>&1

echo "Configuración ÓPTIMA para múltiples cajas:"
echo "  - Banda: 60 pasos, 200ms (más espacio, velocidad media)"
echo "  - 2 Celdas: posiciones 15 y 40"
echo "  - Dispensadores: 6 unidades, 5 sets"
echo "  - Piezas por set: A=3, B=2, C=4, D=1 (10 piezas)"
echo "  - Total: 50 piezas → 5 cajas esperadas"
echo ""

read -p "Presiona Enter para iniciar el sistema..."
echo ""

# 1. Banda más grande y velocidad media
echo "1. Iniciando banda (60 pasos, 200ms)..."
./bin/banda 60 200 &
BANDA_PID=$!
sleep 2
echo "   ✓ Banda activa"

# 2. Primera celda (posición temprana)
echo "2. Iniciando Celda #1 en posición 15..."
./bin/celda 1 15 3 2 4 1 &
CELDA1_PID=$!
sleep 2
echo "   ✓ Celda 1 activa"

# 3. Segunda celda (posición tardía para capturar sobrantes)
echo "3. Iniciando Celda #2 en posición 40..."
./bin/celda 2 40 3 2 4 1 &
CELDA2_PID=$!
sleep 2
echo "   ✓ Celda 2 activa"

# 4. Monitor (opcional)
echo "4. Iniciando monitor..."
./bin/monitor &
MONITOR_PID=$!
sleep 1

if ps -p $MONITOR_PID > /dev/null 2>&1; then
    echo "   ✓ Monitor activo"
else
    echo "   ⚠ Monitor no se inició (opcional)"
    MONITOR_PID=""
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Sistema Completo Activo"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Componentes:"
echo "  ✓ Banda: 60 pasos"
echo "  ✓ Celda #1: posición 15 (captura primero)"
echo "  ✓ Celda #2: posición 40 (captura remanentes)"
echo "  ✓ Monitor: visualización"
echo ""
echo "Objetivo: Completar 5 cajas (50 piezas)"
echo ""
echo "Observa:"
echo "  - Ambas celdas trabajando simultáneamente"
echo "  - Celda 1 capturando la mayoría"
echo "  - Celda 2 capturando lo que Celda 1 dejó pasar"
echo "  - Mensajes '✅ OK' de ambas celdas"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# 5. Dispensadores - 6 unidades, 5 sets
./bin/dispensadores 6 5 3 2 4 1 100000

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Dispensado Completado"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Dando 30 segundos para que las celdas terminen..."
sleep 30

echo ""
echo "Finalizando sistema..."

# Detener procesos
if [ -n "$MONITOR_PID" ] && ps -p $MONITOR_PID > /dev/null 2>&1; then
    kill $MONITOR_PID 2>/dev/null
fi

if ps -p $CELDA2_PID > /dev/null 2>&1; then
    kill $CELDA2_PID 2>/dev/null
fi

if ps -p $CELDA1_PID > /dev/null 2>&1; then
    kill $CELDA1_PID 2>/dev/null
fi

sleep 2

if ps -p $BANDA_PID > /dev/null 2>&1; then
    kill $BANDA_PID 2>/dev/null
fi

# Limpiar
make clean-ipc > /dev/null 2>&1

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Análisis de Resultados"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Busca en el output arriba:"
echo ""
echo "✅ ÉXITO TOTAL:"
echo "   - 5 cajas OK (Celda 1 + Celda 2 = 5 total)"
echo "   - Pocas o ninguna pieza al tacho"
echo "   - Estadísticas de ambas celdas"
echo ""
echo "✅ ÉXITO PARCIAL:"
echo "   - 3-4 cajas OK (aceptable)"
echo "   - Algunas piezas al tacho"
echo ""
echo "❌ PROBLEMA:"
echo "   - Menos de 2 cajas OK"
echo "   - Muchas piezas al tacho (>20)"
echo ""
echo "════════════════════════════════════════════════════════"