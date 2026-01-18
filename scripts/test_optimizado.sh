#!/bin/bash
# test_optimizado.sh - Configuración optimizada para máxima captura

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║     LEGO MASTER - CONFIGURACIÓN OPTIMIZADA               ║
║     (Máxima captura de piezas)                           ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "Esta configuración optimiza:"
echo "  • Velocidad de banda (más lenta)"
echo "  • Intervalo de dispensado (más lento)"
echo "  • Posicionamiento de celdas"
echo "  • Tiempos de espera"
echo ""

make clean-ipc > /dev/null 2>&1

# ============================================================
#  CONFIGURACIÓN OPTIMIZADA
# ============================================================

# Banda MÁS LENTA para dar tiempo a capturar
BANDA_SIZE=70
BANDA_SPEED=250  # 250ms por paso (muy lento)

# Dispensadores LENTOS
NUM_DISP=4       # Pocos dispensadores = menos saturación
NUM_SETS=3       # 3 sets = 30 piezas (manejable)
PZA=3
PZB=2
PZC=4
PZD=1

# Intervalo MUY LENTO entre dispensados
INTERVALO=250000  # 250ms entre ciclos

# Posiciones de celdas OPTIMIZADAS
CELDA1_POS=20    # Temprana
CELDA2_POS=45    # Media-tardía

echo "Configuración:"
echo "  Banda: $BANDA_SIZE pasos × ${BANDA_SPEED}ms = MUY LENTA"
echo "  Dispensadores: $NUM_DISP × ${INTERVALO}μs = MUY LENTO"
echo "  Sets: $NUM_SETS (30 piezas totales)"
echo "  Celdas: posiciones $CELDA1_POS y $CELDA2_POS"
echo ""
echo "Tiempo estimado: 3-4 minutos"
echo ""

read -p "Presiona Enter para iniciar..."

clear

# ============================================================
#  INICIO DEL SISTEMA
# ============================================================

echo ""
echo "════════════════════════════════════════════════════════"
echo "  INICIANDO SISTEMA OPTIMIZADO"
echo "════════════════════════════════════════════════════════"
echo ""

# 1. Banda
echo "[1/4] Banda transportadora (LENTA)..."
./bin/banda $BANDA_SIZE $BANDA_SPEED > /tmp/opt_banda.log 2>&1 &
BANDA_PID=$!
sleep 2

if ! ps -p $BANDA_PID > /dev/null 2>&1; then
    echo "      ❌ Error en banda"
    exit 1
fi
echo "      ✓ Banda OK (PID: $BANDA_PID)"

# 2. Dispensadores
echo "[2/4] Dispensadores (LENTOS)..."
./bin/dispensadores $NUM_DISP $NUM_SETS $PZA $PZB $PZC $PZD $INTERVALO > /tmp/opt_disp.log 2>&1 &
DISP_PID=$!
sleep 3

if ps -p $DISP_PID > /dev/null 2>&1; then
    echo "      ✓ Dispensadores OK (PID: $DISP_PID)"
    DISP_ACTIVO=1
else
    echo "      ⚠️  Dispensadores ya terminaron"
    DISP_ACTIVO=0
fi

# 3. Celda 1 (Posición temprana)
echo "[3/4] Celda 1 (posición $CELDA1_POS)..."
./bin/celda 1 $CELDA1_POS $PZA $PZB $PZC $PZD > /tmp/opt_celda1.log 2>&1 &
CELDA1_PID=$!
sleep 2

if ! ps -p $CELDA1_PID > /dev/null 2>&1; then
    echo "      ❌ Error en celda 1"
    kill $DISP_PID $BANDA_PID 2>/dev/null
    exit 1
fi
echo "      ✓ Celda 1 OK (PID: $CELDA1_PID)"

# 4. Celda 2 (Posición media)
echo "[4/4] Celda 2 (posición $CELDA2_POS)..."
./bin/celda 2 $CELDA2_POS $PZA $PZB $PZC $PZD > /tmp/opt_celda2.log 2>&1 &
CELDA2_PID=$!
sleep 2

if ps -p $CELDA2_PID > /dev/null 2>&1; then
    echo "      ✓ Celda 2 OK (PID: $CELDA2_PID)"
    TIENE_CELDA2=1
else
    echo "      ⚠️  Celda 2 falló (solo usaremos 1)"
    CELDA2_PID=""
    TIENE_CELDA2=0
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  SISTEMA ACTIVO"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Observa los logs en tiempo real:"
echo "  tail -f /tmp/opt_disp.log"
echo "  tail -f /tmp/opt_celda1.log"
echo ""

# ============================================================
#  MONITOREO
# ============================================================

if [ $DISP_ACTIVO -eq 1 ]; then
    echo "Monitoreando dispensado..."
    echo ""
    
    SEGUNDOS=0
    while ps -p $DISP_PID > /dev/null 2>&1; do
        sleep 5
        SEGUNDOS=$((SEGUNDOS + 5))
        
        # Extraer progreso
        if [ -f /tmp/opt_disp.log ]; then
            ULTIMO=$(tail -5 /tmp/opt_disp.log | grep -E "(Ciclo|Progreso)" | tail -1)
            [ -n "$ULTIMO" ] && echo "  [${SEGUNDOS}s] $ULTIMO"
        fi
    done
    
    echo ""
    echo "✓ Dispensado completado en ${SEGUNDOS}s"
else
    echo "Dispensadores ya finalizaron"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  PROCESAMIENTO FINAL"
echo "════════════════════════════════════════════════════════"
echo ""

echo "Esperando que las últimas piezas lleguen a las celdas..."
echo "Banda: $BANDA_SIZE pasos × ${BANDA_SPEED}ms = $((BANDA_SIZE * BANDA_SPEED / 1000))s de recorrido"
echo ""

# Esperar tiempo suficiente para que TODAS las piezas recorran la banda
TIEMPO_BANDA=$((BANDA_SIZE * BANDA_SPEED / 1000 + 10))
echo "Esperando ${TIEMPO_BANDA} segundos..."

for i in $(seq 1 $TIEMPO_BANDA); do
    sleep 1
    [ $((i % 10)) -eq 0 ] && echo "  $i/${TIEMPO_BANDA}s..."
done

echo ""
echo "Procesamiento final completado"

# ============================================================
#  FINALIZACIÓN
# ============================================================

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FINALIZANDO SISTEMA"
echo "════════════════════════════════════════════════════════"
echo ""

# Detener celdas
echo "Enviando señal de terminación a celdas..."
[ -n "$CELDA2_PID" ] && ps -p $CELDA2_PID > /dev/null 2>&1 && kill -INT $CELDA2_PID 2>/dev/null
ps -p $CELDA1_PID > /dev/null 2>&1 && kill -INT $CELDA1_PID 2>/dev/null

echo "Esperando que celdas finalicen..."
sleep 5

# Detener banda
ps -p $BANDA_PID > /dev/null 2>&1 && kill -INT $BANDA_PID 2>/dev/null
sleep 2

# Limpiar IPC
make clean-ipc > /dev/null 2>&1

echo "✓ Sistema detenido"

clear

# ============================================================
#  REPORTES FINALES
# ============================================================

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║            RESULTADOS - CONFIGURACIÓN OPTIMIZADA         ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "════════════════════════════════════════════════════════"
echo "  CELDA 1 (Posición $CELDA1_POS)"
echo "════════════════════════════════════════════════════════"
echo ""
if [ -f /tmp/opt_celda1.log ]; then
    if grep -q "RESUMEN FINAL" /tmp/opt_celda1.log; then
        sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/opt_celda1.log
    else
        echo "Estadísticas de brazos:"
        grep "Finalizado - Procesó" /tmp/opt_celda1.log
        echo ""
        echo "Cajas:"
        grep -E "(✅ OK|❌ FAIL)" /tmp/opt_celda1.log | head -10
    fi
else
    echo "❌ Log no encontrado"
fi

echo ""

if [ $TIENE_CELDA2 -eq 1 ]; then
    echo "════════════════════════════════════════════════════════"
    echo "  CELDA 2 (Posición $CELDA2_POS)"
    echo "════════════════════════════════════════════════════════"
    echo ""
    if [ -f /tmp/opt_celda2.log ]; then
        if grep -q "RESUMEN FINAL" /tmp/opt_celda2.log; then
            sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/opt_celda2.log
        else
            echo "Estadísticas de brazos:"
            grep "Finalizado - Procesó" /tmp/opt_celda2.log
            echo ""
            echo "Cajas:"
            grep -E "(✅ OK|❌ FAIL)" /tmp/opt_celda2.log | head -10
        fi
    fi
    echo ""
fi

# Análisis
CAJAS_OK=$(grep -h "✅ OK" /tmp/opt_celda*.log 2>/dev/null | wc -l)
CAJAS_FAIL=$(grep -h "❌ FAIL" /tmp/opt_celda*.log 2>/dev/null | wc -l)
SUSPENSIONES=$(grep -h "💤 Suspendido" /tmp/opt_celda*.log 2>/dev/null | wc -l)
TACHO=$(grep -h "\[TACHO\]" /tmp/opt_banda.log 2>/dev/null | wc -l)

# Piezas procesadas por cada celda
PIEZAS_C1=0
PIEZAS_C2=0

if [ -f /tmp/opt_celda1.log ]; then
    for n in $(grep "Finalizado - Procesó" /tmp/opt_celda1.log | grep -oP '\d+ piezas' | grep -oP '\d+'); do
        PIEZAS_C1=$((PIEZAS_C1 + n))
    done
fi

if [ -f /tmp/opt_celda2.log ]; then
    for n in $(grep "Finalizado - Procesó" /tmp/opt_celda2.log | grep -oP '\d+ piezas' | grep -oP '\d+'); do
        PIEZAS_C2=$((PIEZAS_C2 + n))
    done
fi

TOTAL_PROCESADAS=$((PIEZAS_C1 + PIEZAS_C2))
TOTAL_ESPERADAS=$((NUM_SETS * (PZA + PZB + PZC + PZD)))

echo "════════════════════════════════════════════════════════"
echo "  ANÁLISIS GLOBAL"
echo "════════════════════════════════════════════════════════"
echo ""

echo "📊 PIEZAS:"
echo "   Total dispensadas: $TOTAL_ESPERADAS"
echo "   Procesadas por celdas: $TOTAL_PROCESADAS"
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

echo "⚖️  BALANCE:"
echo "   Suspensiones: $SUSPENSIONES"
echo ""

echo "🎯 DISTRIBUCIÓN:"
echo "   Celda 1 procesó: $PIEZAS_C1 piezas ($((PIEZAS_C1 * 100 / (TOTAL_PROCESADAS + 1)))%)"
echo "   Celda 2 procesó: $PIEZAS_C2 piezas ($((PIEZAS_C2 * 100 / (TOTAL_PROCESADAS + 1)))%)"
echo ""

echo "════════════════════════════════════════════════════════"
echo "  EVALUACIÓN"
echo "════════════════════════════════════════════════════════"
echo ""

# Evaluaciones
if [ $CAJAS_OK -eq $NUM_SETS ]; then
    echo "  ✅ EXCELENTE: Todos los sets completados"
elif [ $CAJAS_OK -ge $((NUM_SETS * 2 / 3)) ]; then
    echo "  ✓ BUENO: Mayoría de sets completados ($CAJAS_OK/$NUM_SETS)"
else
    echo "  ⚠️  REGULAR: Pocos sets completados ($CAJAS_OK/$NUM_SETS)"
fi

if [ $((TOTAL_PROCESADAS * 100 / TOTAL_ESPERADAS)) -ge 80 ]; then
    echo "  ✅ EFICIENCIA ALTA: >80% de piezas capturadas"
elif [ $((TOTAL_PROCESADAS * 100 / TOTAL_ESPERADAS)) -ge 60 ]; then
    echo "  ✓ EFICIENCIA MEDIA: 60-80% capturadas"
else
    echo "  ⚠️  EFICIENCIA BAJA: <60% capturadas"
fi

if [ $SUSPENSIONES -gt 0 ]; then
    echo "  ✅ BALANCE ACTIVO: $SUSPENSIONES suspensiones"
else
    echo "  ⚠️  SIN BALANCE: No se detectaron suspensiones"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo ""
echo "Logs detallados:"
echo "  /tmp/opt_celda1.log"
[ $TIENE_CELDA2 -eq 1 ] && echo "  /tmp/opt_celda2.log"
echo "  /tmp/opt_disp.log"
echo "  /tmp/opt_banda.log"
echo ""
echo "🎉 Prueba optimizada completada"
echo ""