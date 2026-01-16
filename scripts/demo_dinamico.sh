#!/bin/bash
# demo_dinamico.sh - Demostración de agregar/quitar celdas dinámicamente

echo "════════════════════════════════════════════════════════"
echo "  Demostración: Celdas Dinámicas (Día 5)"
echo "════════════════════════════════════════════════════════"
echo ""

make clean-ipc > /dev/null 2>&1

echo "Esta demostración muestra:"
echo "  1. Sistema inicia con 1 celda"
echo "  2. Se agregan 2 celdas más MIENTRAS el sistema corre"
echo "  3. Se quita 1 celda MIENTRAS el sistema corre"
echo "  4. El sistema continúa funcionando sin interrupciones"
echo ""

read -p "Presiona Enter para comenzar..."
echo ""

# Fase 1: Sistema básico
echo "═══════════════════════════════════════════════════════"
echo "  FASE 1: Iniciando sistema con 1 celda"
echo "═══════════════════════════════════════════════════════"
echo ""

./bin/banda 70 150 &
BANDA_PID=$!
sleep 2
echo "✓ Banda iniciada"

./bin/celda 1 20 3 2 4 1 &
CELDA1_PID=$!
sleep 2
echo "✓ Celda 1 iniciada (posición 20)"

./bin/monitor &
MONITOR_PID=$!
sleep 1
echo "✓ Monitor iniciado"

./bin/dispensadores 8 15 3 2 4 1 100000 &
DISP_PID=$!
sleep 3
echo "✓ Dispensadores iniciados (15 sets)"

echo ""
echo "Sistema corriendo con 1 celda..."
sleep 5

# Fase 2: Agregar segunda celda
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  FASE 2: Agregando Celda 2 (posición 40)"
echo "═══════════════════════════════════════════════════════"
echo ""

./bin/celda 2 40 3 2 4 1 &
CELDA2_PID=$!
sleep 2

if ps -p $CELDA2_PID > /dev/null 2>&1; then
    echo "✓ Celda 2 agregada dinámicamente"
    echo "  → Ahora hay 2 celdas capturando piezas"
else
    echo "⚠ Celda 2 no se agregó correctamente"
    CELDA2_PID=""
fi

sleep 8

# Fase 3: Agregar tercera celda
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  FASE 3: Agregando Celda 3 (posición 55)"
echo "═══════════════════════════════════════════════════════"
echo ""

./bin/celda 3 55 3 2 4 1 &
CELDA3_PID=$!
sleep 2

if ps -p $CELDA3_PID > /dev/null 2>&1; then
    echo "✓ Celda 3 agregada dinámicamente"
    echo "  → Ahora hay 3 celdas capturando piezas"
else
    echo "⚠ Celda 3 no se agregó correctamente"
    CELDA3_PID=""
fi

sleep 8

# Fase 4: Quitar celda 2
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  FASE 4: Quitando Celda 2 dinámicamente"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ -n "$CELDA2_PID" ] && ps -p $CELDA2_PID > /dev/null 2>&1; then
    kill $CELDA2_PID
    sleep 2
    echo "✓ Celda 2 removida"
    echo "  → Quedan Celdas 1 y 3 operando"
    echo "  → El sistema continúa sin interrupciones"
else
    echo "⚠ Celda 2 ya no estaba activa"
fi

sleep 10

# Fase 5: Finalización
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  FASE 5: Esperando finalización del dispensado"
echo "═══════════════════════════════════════════════════════"
echo ""

# Esperar a que terminen los dispensadores
if ps -p $DISP_PID > /dev/null 2>&1; then
    echo "Esperando que los dispensadores terminen..."
    wait $DISP_PID 2>/dev/null
fi

echo "Dispensado completado"
echo ""
echo "Esperando 20 segundos para procesamiento final..."
sleep 20

# Finalizar sistema
echo ""
echo "Finalizando sistema..."

if [ -n "$MONITOR_PID" ] && ps -p $MONITOR_PID > /dev/null 2>&1; then
    kill $MONITOR_PID 2>/dev/null
fi

if [ -n "$CELDA3_PID" ] && ps -p $CELDA3_PID > /dev/null 2>&1; then
    kill $CELDA3_PID 2>/dev/null
fi

if ps -p $CELDA1_PID > /dev/null 2>&1; then
    kill $CELDA1_PID 2>/dev/null
fi

sleep 2

if ps -p $BANDA_PID > /dev/null 2>&1; then
    kill $BANDA_PID 2>/dev/null
fi

make clean-ipc > /dev/null 2>&1

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✓ Demostración Completada"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Has visto:"
echo "  ✓ Sistema iniciado con 1 celda"
echo "  ✓ 2 celdas agregadas dinámicamente"
echo "  ✓ 1 celda removida dinámicamente"
echo "  ✓ Sistema continuó operando sin interrupciones"
echo ""
echo "Busca en el output arriba:"
echo "  - Mensajes de '[CELDA N] Desregistrada de la banda'"
echo "  - Celdas activas cambiando de 1 → 2 → 3 → 2"
echo "  - Resúmenes de las 3 celdas (aunque 1 fue removida)"
echo ""