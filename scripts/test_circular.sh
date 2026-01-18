#!/bin/bash
# test_circular.sh - Prueba con banda circular real

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║     LEGO MASTER - BANDA CIRCULAR                         ║
║     (Las piezas dan la vuelta completa)                  ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "Esta configuración implementa banda CIRCULAR:"
echo "  • Las piezas que llegan al final regresan al inicio"
echo "  • Dan vueltas hasta ser capturadas"
echo "  • Solo caen al tacho si la banda está saturada"
echo ""
echo "Ventaja: Las celdas tienen múltiples oportunidades"
echo "         de capturar las piezas que necesitan"
echo ""

make clean-ipc > /dev/null 2>&1

# ============================================================
#  CONFIGURACIÓN PARA BANDA CIRCULAR
# ============================================================

BANDA_SIZE=50        # Banda más pequeña = vueltas más rápidas
BANDA_SPEED=200      # Velocidad moderada
NUM_DISP=3           # POCOS dispensadores (para no saturar)
NUM_SETS=3           # 3 sets = 30 piezas
PZA=3
PZB=2
PZC=4
PZD=1
INTERVALO=500000     # LENTO: 500ms entre dispensados (clave!)

# Posiciones de celdas distribuidas
CELDA1_POS=15
CELDA2_POS=35

echo "Configuración CIRCULAR:"
echo "  Banda: $BANDA_SIZE pasos (pequeña para vueltas rápidas)"
echo "  Velocidad: ${BANDA_SPEED}ms por paso"
echo "  Dispensadores: $NUM_DISP (POCOS para no saturar)"
echo "  Intervalo: ${INTERVALO}μs (MUY LENTO)"
echo "  Sets: $NUM_SETS (30 piezas)"
echo ""
echo "  Celda 1: posición $CELDA1_POS"
echo "  Celda 2: posición $CELDA2_POS"
echo ""
echo "Tiempo de una vuelta: $((BANDA_SIZE * BANDA_SPEED / 1000))s"
echo "Las piezas darán varias vueltas antes de ser todas capturadas"
echo ""
echo "Tiempo estimado: 3-4 minutos"
echo ""

read -p "Presiona Enter para iniciar..."

clear

echo ""
echo "════════════════════════════════════════════════════════"
echo "  INICIANDO SISTEMA CIRCULAR"
echo "════════════════════════════════════════════════════════"
echo ""

# 1. Banda
echo "[1/4] Banda transportadora CIRCULAR..."
./bin/banda $BANDA_SIZE $BANDA_SPEED > /tmp/circ_banda.log 2>&1 &
BANDA_PID=$!
sleep 2

if ! ps -p $BANDA_PID > /dev/null 2>&1; then
    echo "❌ Error en banda"
    exit 1
fi
echo "      ✓ Banda OK (PID: $BANDA_PID)"

# 2. Dispensadores LENTOS
echo "[2/4] Dispensadores (MUY LENTOS para no saturar)..."
./bin/dispensadores $NUM_DISP $NUM_SETS $PZA $PZB $PZC $PZD $INTERVALO > /tmp/circ_disp.log 2>&1 &
DISP_PID=$!
sleep 3

if ps -p $DISP_PID > /dev/null 2>&1; then
    echo "      ✓ Dispensadores OK (PID: $DISP_PID)"
    DISP_ACTIVO=1
else
    echo "      ⚠️  Dispensadores ya terminaron"
    DISP_ACTIVO=0
fi

# 3. Celda 1
echo "[3/4] Celda 1 (posición $CELDA1_POS)..."
./bin/celda 1 $CELDA1_POS $PZA $PZB $PZC $PZD > /tmp/circ_celda1.log 2>&1 &
CELDA1_PID=$!
sleep 2

if ! ps -p $CELDA1_PID > /dev/null 2>&1; then
    echo "❌ Error en celda 1"
    kill $DISP_PID $BANDA_PID 2>/dev/null
    exit 1
fi
echo "      ✓ Celda 1 OK (PID: $CELDA1_PID)"

# 4. Celda 2
echo "[4/4] Celda 2 (posición $CELDA2_POS)..."
./bin/celda 2 $CELDA2_POS $PZA $PZB $PZC $PZD > /tmp/circ_celda2.log 2>&1 &
CELDA2_PID=$!
sleep 2

if ps -p $CELDA2_PID > /dev/null 2>&1; then
    echo "      ✓ Celda 2 OK (PID: $CELDA2_PID)"
    TIENE_CELDA2=1
else
    echo "      ⚠️  Celda 2 falló"
    CELDA2_PID=""
    TIENE_CELDA2=0
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  SISTEMA CIRCULAR ACTIVO"
echo "════════════════════════════════════════════════════════"
echo ""
echo "🔄 Las piezas están dando vueltas en la banda"
echo "   Cada vuelta completa toma: $((BANDA_SIZE * BANDA_SPEED / 1000))s"
echo ""
echo "Observa en tiempo real:"
echo "  tail -f /tmp/circ_celda1.log"
echo "  tail -f /tmp/circ_celda2.log"
echo ""

# Monitoreo
if [ $DISP_ACTIVO -eq 1 ]; then
    echo "Esperando dispensado (muy lento para evitar saturación)..."
    echo ""
    
    SEGUNDOS=0
    while ps -p $DISP_PID > /dev/null 2>&1; do
        sleep 5
        SEGUNDOS=$((SEGUNDOS + 5))
        
        CAJAS=$(grep -c "✅ OK" /tmp/circ_celda*.log 2>/dev/null)
        echo "  [${SEGUNDOS}s] Cajas completadas: $CAJAS"
    done
    
    echo ""
    echo "✓ Dispensado completado en ${SEGUNDOS}s"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ESPERANDO VUELTAS FINALES"
echo "════════════════════════════════════════════════════════"
echo ""

# Tiempo para que las piezas den varias vueltas más
TIEMPO_VUELTA=$((BANDA_SIZE * BANDA_SPEED / 1000))
NUM_VUELTAS=5
TIEMPO_ESPERA=$((TIEMPO_VUELTA * NUM_VUELTAS))

echo "Dando tiempo para que las piezas den $NUM_VUELTAS vueltas adicionales..."
echo "($TIEMPO_ESPERA segundos total)"
echo ""

for i in $(seq 1 $TIEMPO_ESPERA); do
    sleep 1
    if [ $((i % 10)) -eq 0 ]; then
        CAJAS=$(grep -c "✅ OK" /tmp/circ_celda*.log 2>/dev/null)
        echo "  $i/${TIEMPO_ESPERA}s - Cajas completadas: $CAJAS"
    fi
done

echo ""
echo "Procesamiento circular completado"

# Finalización
echo ""
echo "════════════════════════════════════════════════════════"
echo "  FINALIZANDO"
echo "════════════════════════════════════════════════════════"
echo ""

[ -n "$CELDA2_PID" ] && ps -p $CELDA2_PID > /dev/null 2>&1 && kill -INT $CELDA2_PID 2>/dev/null
ps -p $CELDA1_PID > /dev/null 2>&1 && kill -INT $CELDA1_PID 2>/dev/null
sleep 5
ps -p $BANDA_PID > /dev/null 2>&1 && kill -INT $BANDA_PID 2>/dev/null
sleep 2

make clean-ipc > /dev/null 2>&1

clear

# ============================================================
#  RESULTADOS
# ============================================================

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║         RESULTADOS - BANDA CIRCULAR                      ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "════════════════════════════════════════════════════════"
echo "  CELDA 1 (Posición $CELDA1_POS)"
echo "════════════════════════════════════════════════════════"
echo ""

if [ -f /tmp/circ_celda1.log ]; then
    if grep -q "RESUMEN FINAL" /tmp/circ_celda1.log; then
        sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/circ_celda1.log
    else
        echo "📊 Brazos:"
        grep "Finalizado - Procesó" /tmp/circ_celda1.log
        echo ""
        echo "📦 Cajas:"
        grep "✅ OK" /tmp/circ_celda1.log || echo "  Ninguna completada"
    fi
fi

echo ""

if [ $TIENE_CELDA2 -eq 1 ]; then
    echo "════════════════════════════════════════════════════════"
    echo "  CELDA 2 (Posición $CELDA2_POS)"
    echo "════════════════════════════════════════════════════════"
    echo ""
    
    if [ -f /tmp/circ_celda2.log ]; then
        if grep -q "RESUMEN FINAL" /tmp/circ_celda2.log; then
            sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/circ_celda2.log
        else
            echo "📊 Brazos:"
            grep "Finalizado - Procesó" /tmp/circ_celda2.log
            echo ""
            echo "📦 Cajas:"
            grep "✅ OK" /tmp/circ_celda2.log || echo "  Ninguna completada"
        fi
    fi
    echo ""
fi

# Análisis
CAJAS_OK=$(grep -h "✅ OK" /tmp/circ_celda*.log 2>/dev/null | wc -l)
CAJAS_FAIL=$(grep -h "❌ FAIL" /tmp/circ_celda*.log 2>/dev/null | wc -l)
SUSPENSIONES=$(grep -h "💤 Suspendido" /tmp/circ_celda*.log 2>/dev/null | wc -l)
TACHO=$(grep -h "\[TACHO\]" /tmp/circ_banda.log 2>/dev/null | wc -l)

# Piezas procesadas
PIEZAS_C1=0
PIEZAS_C2=0

if [ -f /tmp/circ_celda1.log ]; then
    for n in $(grep "Finalizado - Procesó" /tmp/circ_celda1.log | grep -oP '\d+ piezas' | grep -oP '\d+'); do
        PIEZAS_C1=$((PIEZAS_C1 + n))
    done
fi

if [ -f /tmp/circ_celda2.log ]; then
    for n in $(grep "Finalizado - Procesó" /tmp/circ_celda2.log | grep -oP '\d+ piezas' | grep -oP '\d+'); do
        PIEZAS_C2=$((PIEZAS_C2 + n))
    done
fi

TOTAL_PROCESADAS=$((PIEZAS_C1 + PIEZAS_C2))
TOTAL_ESPERADAS=$((NUM_SETS * (PZA + PZB + PZC + PZD)))

echo "════════════════════════════════════════════════════════"
echo "  ANÁLISIS - BANDA CIRCULAR"
echo "════════════════════════════════════════════════════════"
echo ""

echo "📊 PIEZAS:"
echo "   Total dispensadas: $TOTAL_ESPERADAS"
echo "   Procesadas total: $TOTAL_PROCESADAS"
echo "   Caídas al tacho: $TACHO"
echo "   Tasa de captura: $((TOTAL_PROCESADAS * 100 / TOTAL_ESPERADAS))%"
echo ""

echo "📦 CAJAS:"
echo "   Completadas OK: $CAJAS_OK / $NUM_SETS esperados"
echo "   Con errores: $CAJAS_FAIL"
if [ $((CAJAS_OK + CAJAS_FAIL)) -gt 0 ]; then
    echo "   Tasa de éxito: $((CAJAS_OK * 100 / (CAJAS_OK + CAJAS_FAIL)))%"
fi
echo ""

echo "🎯 DISTRIBUCIÓN:"
echo "   Celda 1: $PIEZAS_C1 piezas ($((PIEZAS_C1 * 100 / (TOTAL_PROCESADAS + 1)))%)"
echo "   Celda 2: $PIEZAS_C2 piezas ($((PIEZAS_C2 * 100 / (TOTAL_PROCESADAS + 1)))%)"
echo ""

echo "⚖️  BALANCE:"
echo "   Suspensiones: $SUSPENSIONES"
echo ""

echo "════════════════════════════════════════════════════════"
echo "  EVALUACIÓN BANDA CIRCULAR"
echo "════════════════════════════════════════════════════════"
echo ""

if [ $CAJAS_OK -ge $NUM_SETS ]; then
    echo "  🌟 PERFECTO: Todos los sets completados"
elif [ $CAJAS_OK -ge $((NUM_SETS * 2 / 3)) ]; then
    echo "  ✅ EXCELENTE: Mayoría completada ($CAJAS_OK/$NUM_SETS)"
elif [ $CAJAS_OK -ge $((NUM_SETS / 2)) ]; then
    echo "  ✓ BUENO: Mitad completada ($CAJAS_OK/$NUM_SETS)"
else
    echo "  ⚠️  MEJORABLE: Pocas cajas ($CAJAS_OK/$NUM_SETS)"
fi

if [ $TACHO -eq 0 ]; then
    echo "  🌟 EFICIENCIA PERFECTA: 0 piezas al tacho"
elif [ $TACHO -lt 5 ]; then
    echo "  ✅ EFICIENCIA ALTA: Muy pocas al tacho ($TACHO)"
else
    echo "  ⚠️  SATURACIÓN: $TACHO piezas al tacho (banda saturada)"
fi

echo ""
echo "💡 VENTAJA DE BANDA CIRCULAR:"
if [ $CAJAS_OK -gt 1 ]; then
    echo "  ✅ Múltiples cajas completadas con 2 celdas"
    echo "  ✅ Las piezas tuvieron varias oportunidades"
    echo "  ✅ Mejor distribución que banda lineal"
else
    echo "  ⚠️  Puede necesitar más vueltas o menos dispensadores"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo ""
echo "Logs completos:"
echo "  /tmp/circ_celda1.log"
[ $TIENE_CELDA2 -eq 1 ] && echo "  /tmp/circ_celda2.log"
echo "  /tmp/circ_disp.log"
echo "  /tmp/circ_banda.log"
echo ""
echo "🎉 Prueba con banda circular completada"
echo ""