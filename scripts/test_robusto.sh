#!/bin/bash
# test_robusto.sh - Prueba robusta del sistema con manejo de errores mejorado

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║        LEGO MASTER - SISTEMA DE EMPAQUETADO              ║
║              Prueba Robusta                              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "Estudiante: Luis Vergara Arellano"
echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Limpiar recursos previos
echo "Limpiando recursos IPC previos..."
make clean-ipc > /dev/null 2>&1
sleep 1
echo "✓ Limpieza completada"
echo ""

# Configuración
BANDA_SIZE=60
BANDA_SPEED=150  # Más lento para dar tiempo a capturar
NUM_DISP=4       # Menos dispensadores para que sea más controlado
NUM_SETS=3       # Menos sets para prueba más rápida pero completa
PZA=3
PZB=2
PZC=4
PZD=1
INTERVALO=200000  # MÁS LENTO: 200ms entre ciclos (era 100ms)

echo "════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Banda: $BANDA_SIZE pasos × $BANDA_SPEED ms/paso"
echo "Dispensadores: $NUM_DISP unidades"
echo "Sets a producir: $NUM_SETS"
echo "Piezas por SET: A=$PZA, B=$PZB, C=$PZC, D=$PZD (Total: $((PZA+PZB+PZC+PZD)))"
echo "Total piezas: $((NUM_SETS * (PZA+PZB+PZC+PZD)))"
echo "Celdas: 2 (posiciones 15 y 40)"
echo ""
read -p "Presiona Enter para iniciar..."

clear

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FASE 1: INFRAESTRUCTURA BÁSICA"
echo "════════════════════════════════════════════════════════"
echo ""

# 1. Banda
echo "[1/2] Iniciando banda transportadora..."
./bin/banda $BANDA_SIZE $BANDA_SPEED > /tmp/lego_banda.log 2>&1 &
BANDA_PID=$!
sleep 2

if ps -p $BANDA_PID > /dev/null 2>&1; then
    echo "      ✓ Banda activa (PID: $BANDA_PID)"
else
    echo "      ❌ ERROR: Banda falló"
    tail -10 /tmp/lego_banda.log
    exit 1
fi

# 2. Dispensadores
echo "[2/2] Iniciando dispensadores..."
./bin/dispensadores $NUM_DISP $NUM_SETS $PZA $PZB $PZC $PZD $INTERVALO > /tmp/lego_disp.log 2>&1 &
DISP_PID=$!
sleep 3

# Verificar que al menos se creó el proceso
if [ -z "$DISP_PID" ]; then
    echo "      ❌ ERROR: No se pudo iniciar dispensadores"
    kill $BANDA_PID 2>/dev/null
    exit 1
fi

# Verificar si está corriendo o si ya terminó
if ps -p $DISP_PID > /dev/null 2>&1; then
    echo "      ✓ Dispensadores activos (PID: $DISP_PID)"
    DISP_RUNNING=1
else
    echo "      ⚠️  Dispensadores terminaron muy rápido"
    echo "      Verificando si fue exitoso..."
    if grep -q "Todas las piezas han sido dispensadas" /tmp/lego_disp.log 2>/dev/null; then
        echo "      ✓ Dispensadores completaron exitosamente"
        DISP_RUNNING=0
    else
        echo "      ❌ Dispensadores fallaron"
        tail -10 /tmp/lego_disp.log
        kill $BANDA_PID 2>/dev/null
        exit 1
    fi
fi

sleep 2

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FASE 2: CELDAS DE EMPAQUETADO"
echo "════════════════════════════════════════════════════════"
echo ""

# 3. Celda 1
echo "[1/2] Iniciando Celda #1 (posición 15)..."
./bin/celda 1 15 $PZA $PZB $PZC $PZD > /tmp/lego_celda1.log 2>&1 &
CELDA1_PID=$!
sleep 2

if ps -p $CELDA1_PID > /dev/null 2>&1; then
    echo "      ✓ Celda 1 activa (PID: $CELDA1_PID)"
else
    echo "      ❌ ERROR: Celda 1 falló"
    tail -10 /tmp/lego_celda1.log
    [ -n "$DISP_PID" ] && kill $DISP_PID 2>/dev/null
    kill $BANDA_PID 2>/dev/null
    exit 1
fi

# 4. Celda 2
echo "[2/2] Iniciando Celda #2 (posición 40)..."
./bin/celda 2 40 $PZA $PZB $PZC $PZD > /tmp/lego_celda2.log 2>&1 &
CELDA2_PID=$!
sleep 2

if ps -p $CELDA2_PID > /dev/null 2>&1; then
    echo "      ✓ Celda 2 activa (PID: $CELDA2_PID)"
    TIENE_CELDA2=1
else
    echo "      ⚠️  Celda 2 falló (continuando solo con Celda 1)"
    CELDA2_PID=""
    TIENE_CELDA2=0
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FASE 3: OPERACIÓN"
echo "════════════════════════════════════════════════════════"
echo ""

echo "✓ Sistema completamente activo"
echo ""
echo "Componentes:"
echo "  • Banda:         $BANDA_PID"
echo "  • Dispensadores: $DISP_PID $([ $DISP_RUNNING -eq 0 ] && echo '(finalizado)' || echo '(activo)')"
echo "  • Celda 1:       $CELDA1_PID"
[ $TIENE_CELDA2 -eq 1 ] && echo "  • Celda 2:       $CELDA2_PID"
echo ""

echo "Monitoreo en tiempo real:"
echo "  tail -f /tmp/lego_disp.log      # Dispensado"
echo "  tail -f /tmp/lego_celda1.log    # Celda 1"
[ $TIENE_CELDA2 -eq 1 ] && echo "  tail -f /tmp/lego_celda2.log    # Celda 2"
echo ""

# Esperar dispensadores si están activos
if [ $DISP_RUNNING -eq 1 ]; then
    echo "Esperando finalización del dispensado..."
    echo "(Duración estimada: 1-2 minutos para $NUM_SETS sets)"
    echo ""
    
    # Mostrar progreso cada 5 segundos
    CONTADOR=0
    while ps -p $DISP_PID > /dev/null 2>&1; do
        sleep 5
        CONTADOR=$((CONTADOR + 5))
        if grep -q "Progreso:" /tmp/lego_disp.log 2>/dev/null; then
            PROGRESO=$(grep "Progreso:" /tmp/lego_disp.log | tail -1 | grep -oP '\d+\.\d+%' | tail -1)
            echo "  ⏱ ${CONTADOR}s - Progreso: ${PROGRESO:-calculando...}"
        else
            echo "  ⏱ ${CONTADOR}s - Dispensando..."
        fi
    done
    
    echo ""
    echo "✓ Dispensado completado"
else
    echo "Dispensadores ya finalizaron, saltando espera..."
fi

echo ""
echo "Esperando procesamiento final de piezas..."
echo "(Las últimas piezas deben llegar a las celdas)"
sleep 40  # Más tiempo para que las piezas se procesen

echo ""
echo "════════════════════════════════════════════════════════"
echo "  FASE 4: FINALIZACIÓN"
echo "════════════════════════════════════════════════════════"
echo ""

# Detener celdas
echo "Deteniendo celdas..."
[ -n "$CELDA2_PID" ] && ps -p $CELDA2_PID > /dev/null 2>&1 && kill -INT $CELDA2_PID 2>/dev/null
ps -p $CELDA1_PID > /dev/null 2>&1 && kill -INT $CELDA1_PID 2>/dev/null
sleep 3

# Detener banda
echo "Deteniendo banda..."
ps -p $BANDA_PID > /dev/null 2>&1 && kill -INT $BANDA_PID 2>/dev/null
sleep 1

# Limpiar IPC
make clean-ipc > /dev/null 2>&1

echo "✓ Sistema detenido limpiamente"

clear

# ============================================================
#  REPORTES
# ============================================================

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                 RESULTADOS FINALES                       ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "════════════════════════════════════════════════════════"
echo "  CELDA 1 - RESUMEN"
echo "════════════════════════════════════════════════════════"
echo ""
if [ -f /tmp/lego_celda1.log ]; then
    if grep -q "RESUMEN FINAL" /tmp/lego_celda1.log; then
        sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/lego_celda1.log | head -40
    else
        echo "⚠️  Resumen no disponible"
        echo ""
        echo "Últimas líneas del log:"
        tail -20 /tmp/lego_celda1.log
    fi
else
    echo "❌ Log no encontrado"
fi

echo ""

if [ $TIENE_CELDA2 -eq 1 ]; then
    echo "════════════════════════════════════════════════════════"
    echo "  CELDA 2 - RESUMEN"
    echo "════════════════════════════════════════════════════════"
    echo ""
    if [ -f /tmp/lego_celda2.log ]; then
        if grep -q "RESUMEN FINAL" /tmp/lego_celda2.log; then
            sed -n '/RESUMEN FINAL/,/╚═══/p' /tmp/lego_celda2.log | head -40
        else
            echo "⚠️  Resumen no disponible"
            tail -20 /tmp/lego_celda2.log
        fi
    else
        echo "❌ Log no encontrado"
    fi
    echo ""
fi

echo "════════════════════════════════════════════════════════"
echo "  ANÁLISIS GLOBAL"
echo "════════════════════════════════════════════════════════"
echo ""

# Métricas
CAJAS_OK=$(grep -h "✅ OK" /tmp/lego_celda*.log 2>/dev/null | wc -l)
CAJAS_FAIL=$(grep -h "❌ FAIL" /tmp/lego_celda*.log 2>/dev/null | wc -l)
BALANCE=$(grep -h "💤 Suspendido" /tmp/lego_celda*.log 2>/dev/null | wc -l)
TACHO=$(grep -h "\[TACHO\]" /tmp/lego_banda.log 2>/dev/null | wc -l)

echo "📦 Producción:"
echo "   Cajas OK: $CAJAS_OK"
echo "   Cajas FAIL: $CAJAS_FAIL"
if [ $((CAJAS_OK + CAJAS_FAIL)) -gt 0 ]; then
    TASA=$((CAJAS_OK * 100 / (CAJAS_OK + CAJAS_FAIL)))
    echo "   Tasa de éxito: ${TASA}%"
fi
echo ""

echo "⚖️  Balance de brazos:"
echo "   Suspensiones detectadas: $BALANCE"
echo ""

echo "♻️  Eficiencia:"
echo "   Piezas al tacho: $TACHO"
echo ""

echo "════════════════════════════════════════════════════════"
echo ""

# Evaluación
echo "EVALUACIÓN:"
echo ""
[ $CAJAS_OK -ge 3 ] && echo "  ✅ Producción exitosa" || echo "  ⚠️  Producción baja"
[ $BALANCE -gt 0 ] && echo "  ✅ Balance implementado" || echo "  ⚠️  Balance no observado"
[ $TACHO -lt 15 ] && echo "  ✅ Eficiencia alta" || echo "  ⚠️  Muchas piezas perdidas"

echo ""
echo "════════════════════════════════════════════════════════"
echo ""
echo "Logs guardados en:"
echo "  /tmp/lego_banda.log"
echo "  /tmp/lego_celda1.log"
[ $TIENE_CELDA2 -eq 1 ] && echo "  /tmp/lego_celda2.log"
echo "  /tmp/lego_disp.log"
echo ""
echo "Para ver detalles:"
echo "  cat /tmp/lego_celda1.log | less"
echo ""
echo "🎉 Prueba completada"
echo ""