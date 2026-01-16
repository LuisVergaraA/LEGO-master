#!/bin/bash
# test_dia3.sh - Script de prueba para el Día 3 (Celdas completas)

echo "════════════════════════════════════════════════════════"
echo "  Prueba Día 3 - Sistema Completo con Celdas"
echo "════════════════════════════════════════════════════════"
echo ""

# Verificar ejecutables
if [ ! -f "bin/banda" ] || [ ! -f "bin/dispensadores" ] || [ ! -f "bin/celda" ]; then
    echo "❌ Error: Faltan ejecutables"
    echo "Ejecuta: make all"
    exit 1
fi

# Limpiar recursos IPC
echo "1. Limpiando recursos IPC anteriores..."
make clean-ipc > /dev/null 2>&1
echo "   ✓ Limpio"

echo ""
echo "2. Configuración del sistema:"
echo "   - Banda: 50 pasos, 100ms"
echo "   - Dispensadores: 4 unidades, 3 sets"
echo "   - Piezas por set: A=3, B=2, C=4, D=1"
echo "   - Celdas: 2 en posiciones 20 y 35"
echo ""
echo "3. Iniciando componentes..."
echo ""

# Iniciar banda
echo "   [1/4] Iniciando banda transportadora..."
./bin/banda 50 100 &
BANDA_PID=$!
sleep 1

if ! ps -p $BANDA_PID > /dev/null; then
    echo "   ❌ Error: Banda no se inició"
    exit 1
fi
echo "   ✓ Banda iniciada (PID: $BANDA_PID)"

# Iniciar celdas ANTES de los dispensadores
echo "   [2/4] Iniciando celda #1 en posición 20..."
./bin/celda 1 20 3 2 4 1 &
CELDA1_PID=$!
sleep 1

if ! ps -p $CELDA1_PID > /dev/null; then
    echo "   ❌ Error: Celda 1 no se inició"
    kill $BANDA_PID 2>/dev/null
    exit 1
fi
echo "   ✓ Celda 1 iniciada (PID: $CELDA1_PID)"

echo "   [3/4] Iniciando celda #2 en posición 35..."
./bin/celda 2 35 3 2 4 1 &
CELDA2_PID=$!
sleep 1

if ! ps -p $CELDA2_PID > /dev/null; then
    echo "   ⚠ Celda 2 no se inició (solo 1 celda funcionará)"
    CELDA2_PID=""
else
    echo "   ✓ Celda 2 iniciada (PID: $CELDA2_PID)"
fi

# Iniciar monitor (opcional)
echo "   [4/4] Iniciando monitor..."
./bin/monitor &
MONITOR_PID=$!
sleep 1

if ! ps -p $MONITOR_PID > /dev/null; then
    echo "   ⚠ Monitor no se inició (opcional)"
    MONITOR_PID=""
else
    echo "   ✓ Monitor iniciado (PID: $MONITOR_PID)"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  SISTEMA EN EJECUCIÓN"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Componentes activos:"
echo "  ✓ Banda transportadora"
echo "  ✓ Celda #1 (posición 20) - 4 brazos robóticos"
if [ -n "$CELDA2_PID" ]; then
    echo "  ✓ Celda #2 (posición 35) - 4 brazos robóticos"
fi
if [ -n "$MONITOR_PID" ]; then
    echo "  ✓ Monitor de visualización"
fi
echo ""
echo "Observa:"
echo "  - Las piezas siendo capturadas por las celdas"
echo "  - Mensajes de 'OK' cuando se completan cajas"
echo "  - Estadísticas de cada brazo robótico"
echo "  - Las celdas compitiendo por las piezas"
echo ""
echo "El sistema correrá hasta completar los 3 sets..."
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# Ejecutar dispensadores (bloqueará hasta terminar)
./bin/dispensadores 4 3 3 2 4 1 50000

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Dispensado completado, esperando procesamiento..."
echo "════════════════════════════════════════════════════════"
echo ""

# Dar tiempo para que las celdas procesen las últimas piezas
echo "Esperando 5 segundos para que las celdas terminen..."
sleep 5

echo ""
echo "Finalizando sistema..."
echo ""

# Detener procesos
if [ -n "$MONITOR_PID" ] && ps -p $MONITOR_PID > /dev/null 2>&1; then
    kill $MONITOR_PID 2>/dev/null
    echo "  ✓ Monitor detenido"
fi

if [ -n "$CELDA2_PID" ] && ps -p $CELDA2_PID > /dev/null 2>&1; then
    kill $CELDA2_PID 2>/dev/null
    echo "  ✓ Celda 2 detenida"
fi

if ps -p $CELDA1_PID > /dev/null 2>&1; then
    kill $CELDA1_PID 2>/dev/null
    echo "  ✓ Celda 1 detenida"
fi

if ps -p $BANDA_PID > /dev/null 2>&1; then
    kill $BANDA_PID 2>/dev/null
    wait $BANDA_PID 2>/dev/null
    echo "  ✓ Banda detenida"
fi

# Limpiar recursos IPC
echo ""
echo "Limpiando recursos IPC..."
make clean-ipc > /dev/null 2>&1
echo "  ✓ Recursos limpiados"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✓ Prueba Completada"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Verifica en el output arriba:"
echo "  ✓ Mensajes '[OPERADOR] ✅ OK' para cajas correctas"
echo "  ✓ Resumen de cada celda con estadísticas"
echo "  ✓ Número de piezas procesadas por cada brazo"
echo ""
echo "Si viste cajas completándose, ¡el sistema funciona! 🎉"
echo ""
echo "Siguiente paso:"
echo "  - Día 4: Balance de brazos y validación avanzada"
echo "  - Día 5: Celdas dinámicas y robustez"
echo ""