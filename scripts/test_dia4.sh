#!/bin/bash
# test_dia4.sh - Prueba completa del Día 4 (Balance de brazos)

echo "════════════════════════════════════════════════════════"
echo "  Día 4: Balance de Brazos y Reportes Avanzados"
echo "════════════════════════════════════════════════════════"
echo ""

# Limpiar IPC
make clean-ipc > /dev/null 2>&1

echo "Configuración del Día 4:"
echo "  - Banda: 70 pasos, 150ms (más espacio, más rápida)"
echo "  - 3 Celdas: posiciones 15, 30, 50"
echo "  - Dispensadores: 8 unidades, 10 sets"
echo "  - Total: 100 piezas → 10 cajas esperadas"
echo ""
echo "Características Día 4:"
echo "  ✓ Balance de brazos (suspensión cada 4 piezas)"
echo "  ✓ Reportes detallados por celda"
echo "  ✓ Estadísticas de desbalance"
echo "  ✓ Tasa de éxito por celda"
echo ""

read -p "Presiona Enter para iniciar..."
echo ""

# 1. Banda
echo "1. Iniciando banda (70 pasos, 150ms)..."
./bin/banda 70 150 &
BANDA_PID=$!
sleep 2
echo "   ✓ Banda activa"

# 2. Celda 1 (temprana)
echo "2. Iniciando Celda #1 en posición 15..."
./bin/celda 1 15 3 2 4 1 &
CELDA1_PID=$!
sleep 2
echo "   ✓ Celda 1 activa"

# 3. Celda 2 (media)
echo "3. Iniciando Celda #2 en posición 30..."
./bin/celda 2 30 3 2 4 1 &
CELDA2_PID=$!
sleep 2
echo "   ✓ Celda 2 activa"

# 4. Celda 3 (tardía)
echo "4. Iniciando Celda #3 en posición 50..."
./bin/celda 3 50 3 2 4 1 &
CELDA3_PID=$!
sleep 2
echo "   ✓ Celda 3 activa"

# 5. Monitor
echo "5. Iniciando monitor..."
./bin/monitor &
MONITOR_PID=$!
sleep 1

if ps -p $MONITOR_PID > /dev/null 2>&1; then
    echo "   ✓ Monitor activo"
else
    MONITOR_PID=""
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Sistema Completo - Día 4 Activo"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Componentes:"
echo "  ✓ Banda: 70 pasos, 150ms"
echo "  ✓ Celda #1: posición 15"
echo "  ✓ Celda #2: posición 30"
echo "  ✓ Celda #3: posición 50"
echo "  ✓ Monitor: visualización"
echo ""
echo "Objetivo: Completar 10 cajas (100 piezas)"
echo ""
echo "Observa en el output:"
echo "  - Mensajes '💤 Suspendido por balance'"
echo "  - Las 3 celdas trabajando simultáneamente"
echo "  - Reportes detallados al final"
echo "  - Balance de carga entre brazos"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# 6. Dispensadores - 8 unidades, 10 sets
./bin/dispensadores 8 10 3 2 4 1 80000

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Dispensado Completado"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Dando 40 segundos para que las celdas terminen..."
sleep 40

echo ""
echo "Finalizando sistema..."

# Detener procesos
if [ -n "$MONITOR_PID" ] && ps -p $MONITOR_PID > /dev/null 2>&1; then
    kill $MONITOR_PID 2>/dev/null
fi

if ps -p $CELDA3_PID > /dev/null 2>&1; then
    kill $CELDA3_PID 2>/dev/null
fi

if ps -p $CELDA2_PID > /dev/null 2>&1; then
    kill $CELDA2_PID 2>/dev/null
fi

if ps -p $CELDA1_PID > /dev/null 2>&1; then
    kill $CELDA1_PID 2>/dev/null
fi

sleep 3

if ps -p $BANDA_PID > /dev/null 2>&1; then
    kill $BANDA_PID 2>/dev/null
fi

# Limpiar
make clean-ipc > /dev/null 2>&1

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Análisis de Resultados - Día 4"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Busca en el output arriba:"
echo ""
echo "✅ BALANCE DE BRAZOS:"
echo "   - Mensajes '[BRAZO N] 💤 Suspendido por balance'"
echo "   - Desbalance < 25% (bueno)"
echo "   - Desbalance < 10% (excelente)"
echo ""
echo "✅ PRODUCCIÓN:"
echo "   - Total cajas OK: 8-10 (ideal)"
echo "   - Tasa de éxito: > 90%"
echo "   - Piezas al tacho: < 10"
echo ""
echo "✅ REPORTES:"
echo "   - Estadísticas detalladas por celda"
echo "   - Porcentajes de procesamiento por brazo"
echo "   - Balance de carga calculado"
echo ""
echo "════════════════════════════════════════════════════════"