#!/bin/bash
# test_dia2.sh - Script de prueba para el Día 2

echo "════════════════════════════════════════════════════════"
echo "  Prueba Día 2 - Dispensadores y Monitor"
echo "════════════════════════════════════════════════════════"
echo ""

# Verificar que los ejecutables existen
if [ ! -f "bin/banda" ] || [ ! -f "bin/dispensadores" ] || [ ! -f "bin/monitor" ]; then
    echo "❌ Error: Faltan ejecutables"
    echo "Ejecuta: make all"
    exit 1
fi

# Limpiar recursos IPC anteriores
echo "1. Limpiando recursos IPC anteriores..."
make clean-ipc > /dev/null 2>&1
echo "   ✓ Limpio"

echo ""
echo "2. Iniciando componentes del sistema..."
echo ""

# Iniciar banda en background
echo "   Iniciando banda transportadora (50 pasos, 100ms)..."
./bin/banda 50 100 &
BANDA_PID=$!
sleep 1

# Verificar que la banda está corriendo
if ! ps -p $BANDA_PID > /dev/null; then
    echo "   ❌ Error: Banda no se inició correctamente"
    exit 1
fi
echo "   ✓ Banda iniciada (PID: $BANDA_PID)"

# Iniciar monitor en background
echo "   Iniciando monitor..."
./bin/monitor &
MONITOR_PID=$!
sleep 1

if ! ps -p $MONITOR_PID > /dev/null; then
    echo "   ⚠ Monitor no se inició (opcional)"
    MONITOR_PID=""
else
    echo "   ✓ Monitor iniciado (PID: $MONITOR_PID)"
fi

# Esperar un momento
sleep 1

echo ""
echo "3. Iniciando dispensadores..."
echo "   Configuración: 4 dispensadores, 3 sets"
echo "   Piezas por set: A=3, B=2, C=4, D=1"
echo "   Total: 30 piezas"
echo ""
echo "════════════════════════════════════════════════════════"
echo "  SISTEMA EN EJECUCIÓN"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Para detener:"
echo "  - Presiona Ctrl+C"
echo "  - O espera a que termine el dispensado"
echo ""
echo "Observa:"
echo "  - Monitor mostrando la banda en tiempo real"
echo "  - Piezas moviéndose por la banda"
echo "  - Estadísticas actualizándose"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# Ejecutar dispensadores (este bloqueará hasta terminar o Ctrl+C)
./bin/dispensadores 4 3 3 2 4 1 50000

# Capturar código de salida
DISP_EXIT=$?

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Finalizando sistema..."
echo "════════════════════════════════════════════════════════"
echo ""

# Esperar un poco para que las últimas piezas se procesen
sleep 2

# Detener procesos
echo "Deteniendo procesos..."

if [ -n "$MONITOR_PID" ] && ps -p $MONITOR_PID > /dev/null 2>&1; then
    kill $MONITOR_PID 2>/dev/null
    echo "  ✓ Monitor detenido"
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
if [ $DISP_EXIT -eq 0 ]; then
    echo "  ✓ Prueba completada exitosamente"
else
    echo "  ⚠ Prueba interrumpida (Ctrl+C o error)"
fi
echo "════════════════════════════════════════════════════════"
echo ""
echo "Siguiente paso:"
echo "  - Revisar que las piezas se movieron correctamente"
echo "  - Verificar estadísticas en el monitor"
echo "  - Listo para el Día 3: Celdas de empaquetado"
echo ""