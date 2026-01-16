#!/bin/bash
# test_simple_dia3.sh - Prueba simple y segura del Día 3

echo "════════════════════════════════════════════════════════"
echo "  Prueba Simple Día 3 - 1 Celda"
echo "════════════════════════════════════════════════════════"
echo ""

# Limpiar IPC
make clean-ipc > /dev/null 2>&1

echo "Configuración OPTIMIZADA para captura exitosa:"
echo "  - Banda LENTA (300ms por paso)"
echo "  - Dispensadores LENTOS (200ms intervalo)"  
echo "  - 1 CELDA en posición temprana (15)"
echo "  - 2 sets pequeños (fácil de completar)"
echo ""

read -p "Presiona Enter para iniciar el sistema..."
echo ""

# 1. Banda LENTA
echo "1. Iniciando banda transportadora (lenta)..."
./bin/banda 50 300 &
BANDA_PID=$!
sleep 2
echo "   ✓ Banda activa"

# 2. Celda en posición TEMPRANA
echo "2. Iniciando celda en posición 15 (temprana)..."
./bin/celda 1 15 3 2 4 1 &
CELDA_PID=$!
sleep 3
echo "   ✓ Celda activa con 4 brazos"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Sistema Listo - Iniciando Dispensado"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Observa los mensajes de la celda:"
echo "  - Los brazos capturando piezas"
echo "  - El operador validando (OK/FAIL)"
echo "  - El resumen final con estadísticas"
echo ""

# 3. Dispensadores LENTOS
./bin/dispensadores 4 2 3 2 4 1 200000

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Dispensado completado"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Dando 15 segundos para que la celda termine..."
sleep 15

echo ""
echo "Finalizando sistema..."

# Detener procesos
kill $CELDA_PID 2>/dev/null
sleep 1
kill $BANDA_PID 2>/dev/null
sleep 1

# Limpiar
make clean-ipc > /dev/null 2>&1

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Análisis del Resultado"
echo "════════════════════════════════════════════════════════"
echo ""
echo "En el output de arriba, busca:"
echo ""
echo "✅ ÉXITO si ves:"
echo "   - [OPERADOR] ✅ OK - Caja #N correcta"
echo "   - Cajas completadas OK: 1 o más"
echo "   - Estadísticas por brazo (piezas procesadas)"
echo ""
echo "❌ PROBLEMA si ves:"
echo "   - Cajas con errores: N"
echo "   - Cajas completadas OK: 0"
echo "   - Total piezas procesadas: 0"
echo ""
echo "Si hubo problemas, prueba:"
echo "   1. Banda más lenta: ./bin/banda 50 400"
echo "   2. Celda más temprana: ./bin/celda 1 10 ..."
echo "   3. Menos sets: ./bin/dispensadores 4 1 ..."
echo ""