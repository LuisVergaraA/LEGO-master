#!/bin/bash
# test_completo.sh - Prueba completa del sistema LEGO Master

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║        LEGO MASTER - SISTEMA DE EMPAQUETADO              ║
║              Prueba de Funcionamiento                    ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "Verificando sistema..."
echo ""

# Verificar que los ejecutables existan
if [ ! -f "bin/banda" ] || [ ! -f "bin/dispensadores" ] || [ ! -f "bin/celda" ]; then
    echo "❌ Error: Ejecutables no encontrados"
    echo "   Ejecuta primero: make all"
    exit 1
fi

# Limpiar recursos IPC previos
echo "Limpiando recursos IPC previos..."
make clean-ipc > /dev/null 2>&1
echo "✓ Limpieza completada"
echo ""

# Configuración de la prueba
BANDA_SIZE=60
BANDA_SPEED=200
NUM_DISP=6
NUM_SETS=5
PZA=3
PZB=2
PZC=4
PZD=1
INTERVALO=100000

echo "════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN DE LA PRUEBA"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Banda transportadora:"
echo "  - Tamaño: $BANDA_SIZE pasos"
echo "  - Velocidad: $BANDA_SPEED ms/paso"
echo ""
echo "Dispensadores:"
echo "  - Cantidad: $NUM_DISP dispensadores"
echo "  - Sets a producir: $NUM_SETS"
echo "  - Piezas por SET: A=$PZA, B=$PZB, C=$PZC, D=$PZD"
echo "  - Total piezas: $((NUM_SETS * (PZA + PZB + PZC + PZD)))"
echo ""
echo "Celdas de empaquetado:"
echo "  - Celda 1: Posición 15"
echo "  - Celda 2: Posición 40"
echo "  - 4 brazos robóticos por celda"
echo ""
echo "Características implementadas:"
echo "  ✓ Máximo 2 brazos retiran simultáneamente"
echo "  ✓ Solo 1 brazo deposita a la vez"
echo "  ✓ Balance automático cada $Y_TIPOS_PIEZAS piezas"
echo "  ✓ Validación de cajas por operador"
echo "  ✓ Múltiples piezas por posición en banda"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

read -p "Presiona Enter para iniciar el sistema..."
clear

echo ""
echo "════════════════════════════════════════════════════════"
echo "  INICIANDO COMPONENTES DEL SISTEMA"
echo "════════════════════════════════════════════════════════"
echo ""

# 1. Banda transportadora
echo "[1/5] Iniciando banda transportadora..."
./bin/banda $BANDA_SIZE $BANDA_SPEED > /tmp/lego_banda.log 2>&1 &
BANDA_PID=$!
sleep 2

if ! ps -p $BANDA_PID > /dev/null 2>&1; then
    echo "      ❌ Error: La banda no se inició"
    cat /tmp/lego_banda.log
    exit 1
fi
echo "      ✓ Banda activa (PID: $BANDA_PID)"

# 2. Dispensadores (PRIMERO para crear estadísticas)
echo "[2/5] Iniciando dispensadores en background..."
./bin/dispensadores $NUM_DISP $NUM_SETS $PZA $PZB $PZC $PZD $INTERVALO > /tmp/lego_disp.log 2>&1 &
DISP_PID=$!
sleep 3

if ! ps -p $DISP_PID > /dev/null 2>&1; then
    echo "      ⚠️  Dispensadores terminaron rápidamente o fallaron"
    echo "      Verificando log..."
    if [ -f /tmp/lego_disp.log ]; then
        tail -20 /tmp/lego_disp.log
    fi
    # No matamos el sistema, los dispensadores podrían haber terminado ya
    echo "      Continuando con las celdas..."
else
    echo "      ✓ Dispensadores activos (PID: $DISP_PID)"
fi

# 3. Celda 1 (DESPUÉS de dispensadores)
echo "[3/5] Iniciando Celda #1 (posición 15)..."
./bin/celda 1 15 $PZA $PZB $PZC $PZD > /tmp/lego_celda1.log 2>&1 &
CELDA1_PID=$!
sleep 2

if ! ps -p $CELDA1_PID > /dev/null 2>&1; then
    echo "      ❌ Error: Celda 1 no se inició"
    cat /tmp/lego_celda1.log
    kill $DISP_PID $BANDA_PID 2>/dev/null
    exit 1
fi
echo "      ✓ Celda 1 activa (PID: $CELDA1_PID)"

# 4. Celda 2
echo "[4/5] Iniciando Celda #2 (posición 40)..."
./bin/celda 2 40 $PZA $PZB $PZC $PZD > /tmp/lego_celda2.log 2>&1 &
CELDA2_PID=$!
sleep 2

if ! ps -p $CELDA2_PID > /dev/null 2>&1; then
    echo "      ⚠️  Advertencia: Celda 2 no se inició, continuando con 1 celda"
    CELDA2_PID=""
else
    echo "      ✓ Celda 2 activa (PID: $CELDA2_PID)"
fi

# 5. Monitor (opcional)
echo "[5/5] Monitor deshabilitado (opcional)"
echo ""

echo ""
echo "════════════════════════════════════════════════════════"
echo "  SISTEMA EN OPERACIÓN"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Los componentes están trabajando..."
echo "Observa en /tmp/lego_disp.log para ver:"
echo "  → Piezas siendo dispensadas"
echo ""
echo "Y en /tmp/lego_celda1.log y /tmp/lego_celda2.log:"
echo "  → Brazos capturando piezas"
echo "  → Mensajes de balance (💤 Suspendido)"
echo "  → Validaciones de cajas (✅ OK / ❌ FAIL)"
echo ""
echo "Este proceso tomará aproximadamente 2-3 minutos."
echo ""
echo "Para ver el progreso en tiempo real:"
echo "  Terminal 2: tail -f /tmp/lego_disp.log"
echo "  Terminal 3: tail -f /tmp/lego_celda1.log"
echo ""

# Esperar a que terminen los dispensadores
if [ -n "$DISP_PID" ] && ps -p $DISP_PID > /dev/null 2>&1; then
    echo "Dispensadores aún activos, esperando..."
    wait $DISP_PID 2>/dev/null
    echo "Dispensadores finalizaron"
else
    echo "Dispensadores ya terminaron, esperando procesamiento..."
    sleep 5
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  DISPENSADO COMPLETADO"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Esperando que las celdas procesen las últimas piezas..."
echo "(20 segundos)"
sleep 20

echo ""
echo "Deteniendo sistema..."

# Detener procesos ordenadamente
if [ -n "$CELDA2_PID" ] && ps -p $CELDA2_PID > /dev/null 2>&1; then
    kill -INT $CELDA2_PID 2>/dev/null
    sleep 2
fi

if ps -p $CELDA1_PID > /dev/null 2>&1; then
    kill -INT $CELDA1_PID 2>/dev/null
    sleep 2
fi

if ps -p $BANDA_PID > /dev/null 2>&1; then
    kill -INT $BANDA_PID 2>/dev/null
    sleep 1
fi

# Limpiar recursos
make clean-ipc > /dev/null 2>&1

clear

# Mostrar resultados
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║              RESULTADOS DE LA PRUEBA                     ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "════════════════════════════════════════════════════════"
echo "  RESUMEN CELDA 1"
echo "════════════════════════════════════════════════════════"
echo ""
if [ -f /tmp/lego_celda1.log ]; then
    # Extraer resumen
    if grep -q "RESUMEN FINAL" /tmp/lego_celda1.log; then
        sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/lego_celda1.log
    else
        echo "⚠️  Resumen no disponible"
        tail -15 /tmp/lego_celda1.log | grep -E "(Cajas|piezas|Brazo)" || echo "Sin datos"
    fi
else
    echo "⚠️  Log no encontrado"
fi

echo ""

if [ -n "$CELDA2_PID" ]; then
    echo "════════════════════════════════════════════════════════"
    echo "  RESUMEN CELDA 2"
    echo "════════════════════════════════════════════════════════"
    echo ""
    if [ -f /tmp/lego_celda2.log ]; then
        if grep -q "RESUMEN FINAL" /tmp/lego_celda2.log; then
            sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/lego_celda2.log
        else
            echo "⚠️  Resumen no disponible"
            tail -15 /tmp/lego_celda2.log | grep -E "(Cajas|piezas|Brazo)" || echo "Sin datos"
        fi
    else
        echo "⚠️  Log no encontrado"
    fi
    echo ""
fi

echo "════════════════════════════════════════════════════════"
echo "  ANÁLISIS GLOBAL"
echo "════════════════════════════════════════════════════════"
echo ""

# Contar cajas OK y FAIL
CAJAS_OK=$(grep -h "✅ OK" /tmp/lego_celda*.log 2>/dev/null | wc -l)
CAJAS_FAIL=$(grep -h "❌ FAIL" /tmp/lego_celda*.log 2>/dev/null | wc -l)
PIEZAS_TACHO=$(grep -h "\[TACHO\]" /tmp/lego_banda.log 2>/dev/null | wc -l)
SUSPENSIONES=$(grep -h "💤 Suspendido" /tmp/lego_celda*.log 2>/dev/null | wc -l)

echo "Producción total:"
echo "  • Cajas completadas OK: $CAJAS_OK"
echo "  • Cajas con errores: $CAJAS_FAIL"
if [ $((CAJAS_OK + CAJAS_FAIL)) -gt 0 ]; then
    TASA=$((CAJAS_OK * 100 / (CAJAS_OK + CAJAS_FAIL)))
    echo "  • Tasa de éxito: ${TASA}%"
fi
echo ""

echo "Eficiencia:"
echo "  • Piezas que cayeron al tacho: $PIEZAS_TACHO"
echo "  • Suspensiones por balance: $SUSPENSIONES"
echo ""

echo "════════════════════════════════════════════════════════"
echo ""

# Evaluación
echo "EVALUACIÓN DEL SISTEMA:"
echo ""

if [ $CAJAS_OK -ge 3 ]; then
    echo "✅ PRODUCCIÓN: Exitosa ($CAJAS_OK cajas completadas)"
else
    echo "⚠️  PRODUCCIÓN: Baja ($CAJAS_OK cajas, esperado ≥3)"
fi

if [ $SUSPENSIONES -gt 0 ]; then
    echo "✅ BALANCE: Implementado ($SUSPENSIONES suspensiones detectadas)"
else
    echo "⚠️  BALANCE: No se observaron suspensiones"
fi

if [ $PIEZAS_TACHO -lt 15 ]; then
    echo "✅ EFICIENCIA: Alta (solo $PIEZAS_TACHO piezas perdidas)"
else
    echo "⚠️  EFICIENCIA: Media ($PIEZAS_TACHO piezas al tacho)"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo ""
echo "Logs completos guardados en:"
echo "  • /tmp/lego_banda.log"
echo "  • /tmp/lego_celda1.log"
if [ -n "$CELDA2_PID" ]; then
    echo "  • /tmp/lego_celda2.log"
fi
echo "  • /tmp/lego_disp.log"
echo ""
echo "Para ver un log completo:"
echo "  cat /tmp/lego_celda1.log | less"
echo ""
echo "🎉 Prueba completada"
echo ""