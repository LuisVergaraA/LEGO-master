#!/bin/bash
# test_final.sh - La solución correcta: esperar a que se completen las cajas

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║     LEGO MASTER - SOLUCIÓN CORRECTA                      ║
║     (Esperar hasta completar todas las cajas)            ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "Esta es la solución SIMPLE y CORRECTA:"
echo ""
echo "  1. Dispensar todas las piezas"
echo "  2. ESPERAR suficiente tiempo para que:"
echo "     • Todas las piezas recorran la banda"
echo "     • Las celdas capturen lo que necesitan"
echo "     • Se completen TODAS las cajas posibles"
echo "  3. Solo entonces detener el sistema"
echo ""
echo "No necesitamos banda circular, solo PACIENCIA ⏱️"
echo ""

make clean-ipc > /dev/null 2>&1

# ============================================================
#  CONFIGURACIÓN ÓPTIMA
# ============================================================

BANDA_SIZE=60
BANDA_SPEED=200
NUM_DISP=5
NUM_SETS=5           # 5 sets = 50 piezas = 5 cajas posibles
PZA=3
PZB=2
PZC=4
PZD=1
INTERVALO=150000     # Moderado

# Celdas distribuidas uniformemente
CELDA1_POS=20
CELDA2_POS=40

echo "Configuración:"
echo "  Banda: $BANDA_SIZE pasos × ${BANDA_SPEED}ms"
echo "  Dispensadores: $NUM_DISP × ${INTERVALO}μs"
echo "  Sets objetivo: $NUM_SETS (50 piezas = 5 cajas posibles)"
echo ""
echo "  Celda 1: posición $CELDA1_POS"
echo "  Celda 2: posición $CELDA2_POS"
echo ""

# Calcular tiempo mínimo necesario
TIEMPO_RECORRIDO=$((BANDA_SIZE * BANDA_SPEED / 1000))
echo "⏱️  TIEMPOS CALCULADOS:"
echo "  • Una pieza recorre toda la banda: ${TIEMPO_RECORRIDO}s"
echo "  • Tiempo de dispensado estimado: ~$((NUM_SETS * 5))s"

# Tiempo total: dispensado + recorrido completo + margen
TIEMPO_ESPERA_FINAL=$((TIEMPO_RECORRIDO + 20))
echo "  • Espera después de dispensado: ${TIEMPO_ESPERA_FINAL}s"
echo ""
echo "Tiempo total estimado: ~$((NUM_SETS * 5 + TIEMPO_ESPERA_FINAL))s ($(((NUM_SETS * 5 + TIEMPO_ESPERA_FINAL) / 60)) min)"
echo ""

read -p "Presiona Enter para iniciar..."

clear

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FASE 1: INICIANDO COMPONENTES"
echo "════════════════════════════════════════════════════════"
echo ""

# 1. Banda
echo "[1/4] Banda transportadora..."
./bin/banda $BANDA_SIZE $BANDA_SPEED > /tmp/final_banda.log 2>&1 &
BANDA_PID=$!
sleep 2

if ! ps -p $BANDA_PID > /dev/null 2>&1; then
    echo "❌ Error en banda"
    exit 1
fi
echo "      ✓ Banda OK (PID: $BANDA_PID)"

# 2. Dispensadores
echo "[2/4] Dispensadores..."
./bin/dispensadores $NUM_DISP $NUM_SETS $PZA $PZB $PZC $PZD $INTERVALO > /tmp/final_disp.log 2>&1 &
DISP_PID=$!
sleep 3

if ps -p $DISP_PID > /dev/null 2>&1; then
    echo "      ✓ Dispensadores OK (PID: $DISP_PID)"
    DISP_ACTIVO=1
else
    echo "      ⚠️  Dispensadores terminaron rápido"
    DISP_ACTIVO=0
fi

# 3. Celda 1
echo "[3/4] Celda 1 (posición $CELDA1_POS)..."
./bin/celda 1 $CELDA1_POS $PZA $PZB $PZC $PZD > /tmp/final_celda1.log 2>&1 &
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
./bin/celda 2 $CELDA2_POS $PZA $PZB $PZC $PZD > /tmp/final_celda2.log 2>&1 &
CELDA2_PID=$!
sleep 2

if ps -p $CELDA2_PID > /dev/null 2>&1; then
    echo "      ✓ Celda 2 OK (PID: $CELDA2_PID)"
    TIENE_CELDA2=1
else
    echo "      ⚠️  Celda 2 falló (solo 1 celda)"
    CELDA2_PID=""
    TIENE_CELDA2=0
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FASE 2: DISPENSANDO PIEZAS"
echo "════════════════════════════════════════════════════════"
echo ""

if [ $DISP_ACTIVO -eq 1 ]; then
    echo "Monitoreando dispensado..."
    echo "(Ver progreso en tiempo real: tail -f /tmp/final_disp.log)"
    echo ""
    
    SEGUNDOS=0
    while ps -p $DISP_PID > /dev/null 2>&1; do
        sleep 5
        SEGUNDOS=$((SEGUNDOS + 5))
        
        # Contar cajas completadas hasta ahora
        CAJAS=$(grep -c "✅ OK" /tmp/final_celda*.log 2>/dev/null)
        
        # Mostrar progreso
        echo "  ⏱ ${SEGUNDOS}s - Cajas completadas hasta ahora: $CAJAS"
    done
    
    echo ""
    echo "✓ Dispensado completado en ${SEGUNDOS}s"
else
    echo "Dispensadores ya terminaron"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FASE 3: PROCESAMIENTO COMPLETO (CLAVE)"
echo "════════════════════════════════════════════════════════"
echo ""

echo "🔑 ESTA ES LA PARTE CRÍTICA:"
echo ""
echo "Las piezas siguen en la banda y las celdas siguen trabajando."
echo "Esperaremos ${TIEMPO_ESPERA_FINAL}s para que:"
echo "  • Todas las piezas recorran la banda completa"
echo "  • Las celdas capturen todo lo que necesitan"
echo "  • Se completen TODAS las cajas posibles"
echo ""

echo "Monitoreando cajas completadas..."
echo ""

for i in $(seq 1 $TIEMPO_ESPERA_FINAL); do
    sleep 1
    
    # Cada 5 segundos, mostrar progreso
    if [ $((i % 5)) -eq 0 ]; then
        CAJAS_ACTUALES=$(grep -c "✅ OK" /tmp/final_celda*.log 2>/dev/null)
        echo "  ⏱ $i/${TIEMPO_ESPERA_FINAL}s - Cajas: $CAJAS_ACTUALES/$NUM_SETS"
    fi
done

echo ""
CAJAS_FINALES=$(grep -c "✅ OK" /tmp/final_celda*.log 2>/dev/null)
echo "✓ Procesamiento completado - Cajas finales: $CAJAS_FINALES"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FASE 4: FINALIZACIÓN"
echo "════════════════════════════════════════════════════════"
echo ""

echo "Deteniendo sistema..."

# Ahora SÍ detener las celdas
[ -n "$CELDA2_PID" ] && ps -p $CELDA2_PID > /dev/null 2>&1 && kill -INT $CELDA2_PID 2>/dev/null
ps -p $CELDA1_PID > /dev/null 2>&1 && kill -INT $CELDA1_PID 2>/dev/null

echo "Esperando que celdas finalicen limpiamente..."
sleep 5

ps -p $BANDA_PID > /dev/null 2>&1 && kill -INT $BANDA_PID 2>/dev/null
sleep 2

make clean-ipc > /dev/null 2>&1

echo "✓ Sistema detenido limpiamente"

clear

# ============================================================
#  RESULTADOS FINALES
# ============================================================

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║            RESULTADOS FINALES - SOLUCIÓN CORRECTA        ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "════════════════════════════════════════════════════════"
echo "  CELDA 1 - Posición $CELDA1_POS"
echo "════════════════════════════════════════════════════════"
echo ""

if [ -f /tmp/final_celda1.log ]; then
    if grep -q "RESUMEN FINAL" /tmp/final_celda1.log; then
        sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/final_celda1.log
    else
        echo "📊 Estadísticas:"
        grep "Finalizado - Procesó" /tmp/final_celda1.log
        echo ""
        echo "📦 Cajas:"
        grep "✅ OK" /tmp/final_celda1.log | head -5 || echo "  Ninguna"
        [ $(grep -c "✅ OK" /tmp/final_celda1.log 2>/dev/null) -gt 5 ] && echo "  ... (ver log completo)"
    fi
fi

echo ""

if [ $TIENE_CELDA2 -eq 1 ]; then
    echo "════════════════════════════════════════════════════════"
    echo "  CELDA 2 - Posición $CELDA2_POS"
    echo "════════════════════════════════════════════════════════"
    echo ""
    
    if [ -f /tmp/final_celda2.log ]; then
        if grep -q "RESUMEN FINAL" /tmp/final_celda2.log; then
            sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/final_celda2.log
        else
            echo "📊 Estadísticas:"
            grep "Finalizado - Procesó" /tmp/final_celda2.log
            echo ""
            echo "📦 Cajas:"
            grep "✅ OK" /tmp/final_celda2.log | head -5 || echo "  Ninguna"
            [ $(grep -c "✅ OK" /tmp/final_celda2.log 2>/dev/null) -gt 5 ] && echo "  ... (ver log completo)"
        fi
    fi
    echo ""
fi

# ============================================================
#  ANÁLISIS DETALLADO
# ============================================================

echo "════════════════════════════════════════════════════════"
echo "  ANÁLISIS GLOBAL"
echo "════════════════════════════════════════════════════════"
echo ""

CAJAS_OK=$(grep -c "✅ OK" /tmp/final_celda*.log 2>/dev/null)
CAJAS_FAIL=$(grep -c "❌ FAIL" /tmp/final_celda*.log 2>/dev/null)
SUSPENSIONES=$(grep -c "💤 Suspendido" /tmp/final_celda*.log 2>/dev/null)
TACHO=$(grep -c "\[TACHO\]" /tmp/final_banda.log 2>/dev/null)

# Piezas por celda
PIEZAS_C1=0
PIEZAS_C2=0

if [ -f /tmp/final_celda1.log ]; then
    for n in $(grep "Finalizado - Procesó" /tmp/final_celda1.log | grep -oP '\d+ piezas' | grep -oP '\d+'); do
        PIEZAS_C1=$((PIEZAS_C1 + n))
    done
fi

if [ -f /tmp/final_celda2.log ]; then
    for n in $(grep "Finalizado - Procesó" /tmp/final_celda2.log | grep -oP '\d+ piezas' | grep -oP '\d+'); do
        PIEZAS_C2=$((PIEZAS_C2 + n))
    done
fi

TOTAL_PROC=$((PIEZAS_C1 + PIEZAS_C2))
TOTAL_DISP=$((NUM_SETS * (PZA + PZB + PZC + PZD)))

echo "📊 PIEZAS:"
echo "   Total dispensadas: $TOTAL_DISP"
echo "   Procesadas: $TOTAL_PROC ($((TOTAL_PROC * 100 / TOTAL_DISP))%)"
echo "   Al tacho: $TACHO"
echo ""

echo "📦 PRODUCCIÓN:"
echo "   Objetivo: $NUM_SETS cajas"
echo "   Completadas OK: $CAJAS_OK"
echo "   Con errores: $CAJAS_FAIL"
echo "   Tasa de producción: $((CAJAS_OK * 100 / NUM_SETS))%"
if [ $((CAJAS_OK + CAJAS_FAIL)) -gt 0 ]; then
    echo "   Tasa de calidad: $((CAJAS_OK * 100 / (CAJAS_OK + CAJAS_FAIL)))%"
fi
echo ""

echo "🎯 DISTRIBUCIÓN:"
echo "   Celda 1: $PIEZAS_C1 piezas ($((PIEZAS_C1 * 100 / (TOTAL_PROC + 1)))%)"
echo "   Celda 2: $PIEZAS_C2 piezas ($((PIEZAS_C2 * 100 / (TOTAL_PROC + 1)))%)"
echo ""

echo "⚖️  BALANCE:"
echo "   Suspensiones detectadas: $SUSPENSIONES"
echo ""

echo "════════════════════════════════════════════════════════"
echo "  EVALUACIÓN FINAL"
echo "════════════════════════════════════════════════════════"
echo ""

# Evaluación detallada
if [ $CAJAS_OK -eq $NUM_SETS ]; then
    echo "  🌟🌟🌟 PERFECTO: 100% de producción ($CAJAS_OK/$NUM_SETS)"
elif [ $CAJAS_OK -ge $((NUM_SETS * 4 / 5)) ]; then
    echo "  ✅✅ EXCELENTE: >80% producción ($CAJAS_OK/$NUM_SETS)"
elif [ $CAJAS_OK -ge $((NUM_SETS * 3 / 5)) ]; then
    echo "  ✅ BUENO: >60% producción ($CAJAS_OK/$NUM_SETS)"
elif [ $CAJAS_OK -ge $((NUM_SETS / 2)) ]; then
    echo "  ✓ ACEPTABLE: >50% producción ($CAJAS_OK/$NUM_SETS)"
else
    echo "  ⚠️  BAJO: <50% producción ($CAJAS_OK/$NUM_SETS)"
fi

if [ $((TOTAL_PROC * 100 / TOTAL_DISP)) -ge 90 ]; then
    echo "  ✅ EFICIENCIA EXCELENTE: >90% captura"
elif [ $((TOTAL_PROC * 100 / TOTAL_DISP)) -ge 75 ]; then
    echo "  ✓ EFICIENCIA BUENA: 75-90% captura"
else
    echo "  ⚠️  EFICIENCIA MEJORABLE: <75% captura"
fi

if [ $SUSPENSIONES -ge $((NUM_SETS / 2)) ]; then
    echo "  ✅ BALANCE ACTIVO: $SUSPENSIONES suspensiones"
elif [ $SUSPENSIONES -gt 0 ]; then
    echo "  ✓ BALANCE FUNCIONANDO: $SUSPENSIONES suspensiones"
else
    echo "  ⚠️  SIN BALANCE: 0 suspensiones"
fi

if [ $CAJAS_FAIL -eq 0 ]; then
    echo "  ✅ CALIDAD PERFECTA: 0 errores"
else
    echo "  ⚠️  ERRORES DE CALIDAD: $CAJAS_FAIL cajas"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo ""

echo "💡 LA CLAVE DEL ÉXITO:"
echo "  Simplemente ESPERAR el tiempo suficiente para que"
echo "  todas las piezas se procesen ANTES de detener el sistema."
echo ""
echo "  No necesitamos banda circular complicada,"
echo "  solo PACIENCIA y calcular bien los tiempos. ⏱️"
echo ""

echo "════════════════════════════════════════════════════════"
echo ""
echo "Logs completos:"
echo "  /tmp/final_celda1.log"
[ $TIENE_CELDA2 -eq 1 ] && echo "  /tmp/final_celda2.log"
echo "  /tmp/final_disp.log"
echo "  /tmp/final_banda.log"
echo ""
echo "🎉 Sistema completado exitosamente"
echo ""