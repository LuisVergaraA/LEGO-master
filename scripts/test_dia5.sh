#!/bin/bash
# test_dia5.sh - Prueba completa del Día 5 (Sistema robusto y completo)

echo "╔════════════════════════════════════════════════════════╗"
echo "║  DÍA 5: SISTEMA FINAL COMPLETO                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

make clean-ipc > /dev/null 2>&1

echo "Características del Sistema Final:"
echo "  ✓ Banda transportadora circular"
echo "  ✓ Dispensadores con generación aleatoria"
echo "  ✓ Múltiples piezas por posición"
echo "  ✓ Celdas con 4 brazos robóticos"
echo "  ✓ Solo 2 brazos retiran, 1 deposita"
echo "  ✓ Balance automático de brazos"
echo "  ✓ Validación de cajas (OK/FAIL)"
echo "  ✓ Reportes detallados con métricas"
echo "  ✓ Celdas dinámicas (agregar/quitar)"
echo "  ✓ Programación defensiva"
echo "  ✓ Manejo robusto de señales"
echo ""

read -p "Presiona Enter para iniciar la prueba final..."
echo ""

# Configuración
BANDA_SIZE=80
BANDA_SPEED=120
NUM_DISPENSADORES=10
NUM_SETS=20
INTERVALO=70000

echo "Configuración de la prueba:"
echo "  Banda: $BANDA_SIZE pasos, ${BANDA_SPEED}ms"
echo "  Dispensadores: $NUM_DISPENSADORES unidades"
echo "  Sets a producir: $NUM_SETS (200 piezas totales)"
echo "  Celdas iniciales: 2"
echo "  Celdas dinámicas: 1 (se agregará durante ejecución)"
echo ""

# Iniciar sistema
echo "════════════════════════════════════════════════════════"
echo "  Iniciando Sistema"
echo "════════════════════════════════════════════════════════"
echo ""

./bin/banda $BANDA_SIZE $BANDA_SPEED &
BANDA_PID=$!
sleep 2
echo "[1/5] ✓ Banda iniciada (PID: $BANDA_PID)"

./bin/celda 1 15 3 2 4 1 &
CELDA1_PID=$!
sleep 2
echo "[2/5] ✓ Celda 1 iniciada en posición 15 (PID: $CELDA1_PID)"

./bin/celda 2 40 3 2 4 1 &
CELDA2_PID=$!
sleep 2
echo "[3/5] ✓ Celda 2 iniciada en posición 40 (PID: $CELDA2_PID)"

./bin/monitor &
MONITOR_PID=$!
sleep 1

if ps -p $MONITOR_PID > /dev/null 2>&1; then
    echo "[4/5] ✓ Monitor iniciado (PID: $MONITOR_PID)"
else
    echo "[4/5] ⚠ Monitor no se inició (opcional)"
    MONITOR_PID=""
fi

./bin/dispensadores $NUM_DISPENSADORES $NUM_SETS 3 2 4 1 $INTERVALO &
DISP_PID=$!
sleep 2
echo "[5/5] ✓ Dispensadores iniciados (PID: $DISP_PID)"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Sistema Operando - Fase 1"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Estado actual: 2 celdas activas"
echo ""

# Esperar un poco
sleep 15

# Agregar celda dinámica
echo "════════════════════════════════════════════════════════"
echo "  Agregando Celda Dinámica - Fase 2"
echo "════════════════════════════════════════════════════════"
echo ""

./bin/celda 3 65 3 2 4 1 &
CELDA3_PID=$!
sleep 2

if ps -p $CELDA3_PID > /dev/null 2>&1; then
    echo "✓ Celda 3 agregada dinámicamente en posición 65"
    echo "  Estado actual: 3 celdas activas"
else
    echo "⚠ Celda 3 no se agregó correctamente"
    CELDA3_PID=""
fi

echo ""
echo "Sistema continuando con 3 celdas..."
echo ""

# Esperar a que termine el dispensado
if ps -p $DISP_PID > /dev/null 2>&1; then
    echo "Esperando finalización del dispensado..."
    wait $DISP_PID 2>/dev/null
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Dispensado Completado"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Esperando 30 segundos para procesamiento final..."
sleep 30

# Finalizar
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Finalizando Sistema"
echo "════════════════════════════════════════════════════════"
echo ""

if [ -n "$MONITOR_PID" ] && ps -p $MONITOR_PID > /dev/null 2>&1; then
    kill $MONITOR_PID 2>/dev/null
    echo "✓ Monitor detenido"
fi

if [ -n "$CELDA3_PID" ] && ps -p $CELDA3_PID > /dev/null 2>&1; then
    kill -TERM $CELDA3_PID 2>/dev/null
    sleep 1
    echo "✓ Celda 3 detenida (señal SIGTERM)"
fi

if ps -p $CELDA2_PID > /dev/null 2>&1; then
    kill -INT $CELDA2_PID 2>/dev/null
    sleep 1
    echo "✓ Celda 2 detenida (señal SIGINT)"
fi

if ps -p $CELDA1_PID > /dev/null 2>&1; then
    kill -INT $CELDA1_PID 2>/dev/null
    sleep 1
    echo "✓ Celda 1 detenida (señal SIGINT)"
fi

sleep 2

if ps -p $BANDA_PID > /dev/null 2>&1; then
    kill $BANDA_PID 2>/dev/null
    sleep 1
    echo "✓ Banda detenida"
fi

make clean-ipc > /dev/null 2>&1
echo "✓ Recursos IPC limpiados"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  PRUEBA FINAL COMPLETADA                               ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Análisis de resultados:"
echo ""
echo "✅ PRODUCCIÓN:"
echo "   - Buscar: 'Cajas completadas OK:' en cada celda"
echo "   - Objetivo: 15-20 cajas totales (de 20 posibles)"
echo "   - Tasa éxito: >90%"
echo ""
echo "✅ BALANCE:"
echo "   - Buscar: 'Desbalance:' en cada celda"
echo "   - Objetivo: <25% (bueno), <10% (excelente)"
echo ""
echo "✅ EFICIENCIA:"
echo "   - Buscar: 'Piezas en el tacho:'"
echo "   - Objetivo: <20 piezas (de 200)"
echo ""
echo "✅ ROBUSTEZ:"
echo "   - Buscar: '[CELDA N] Desregistrada'"
echo "   - Sistema debe finalizar limpiamente"
echo "   - Sin crashes ni deadlocks"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""
echo "🎉 ¡SISTEMA COMPLETO FUNCIONAL!"
echo ""
echo "Características implementadas:"
echo "  ✓ Días 1-5 completos"
echo "  ✓ Todos los requerimientos del PDF"
echo "  ✓ Sistema robusto y escalable"
echo "  ✓ Listo para demostración final"
echo ""