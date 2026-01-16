#!/bin/bash
# agregar_celda.sh - Agregar una celda dinámicamente al sistema en ejecución

echo "════════════════════════════════════════════════════════"
echo "  Agregar Celda Dinámicamente"
echo "════════════════════════════════════════════════════════"
echo ""

# Verificar que el sistema esté corriendo
if ! pgrep -x "banda" > /dev/null; then
    echo "❌ Error: La banda no está ejecutándose"
    echo "   Inicia el sistema primero."
    exit 1
fi

echo "Sistema detectado en ejecución ✓"
echo ""

# Solicitar parámetros
echo "Parámetros de la nueva celda:"
echo ""

read -p "ID de celda (1-10): " ID
read -p "Posición en banda (0-99): " POS
read -p "Piezas tipo A por set: " PZA
read -p "Piezas tipo B por set: " PZB
read -p "Piezas tipo C por set: " PZC
read -p "Piezas tipo D por set: " PZD

echo ""
echo "Resumen:"
echo "  ID: $ID"
echo "  Posición: $POS"
echo "  SET: A=$PZA, B=$PZB, C=$PZC, D=$PZD"
echo ""

read -p "¿Agregar esta celda? (s/n): " CONFIRMAR

if [ "$CONFIRMAR" != "s" ] && [ "$CONFIRMAR" != "S" ]; then
    echo "Operación cancelada"
    exit 0
fi

echo ""
echo "Agregando celda al sistema..."

# Iniciar celda en background
./bin/celda $ID $POS $PZA $PZB $PZC $PZD &
CELDA_PID=$!

sleep 2

# Verificar que se inició
if ps -p $CELDA_PID > /dev/null 2>&1; then
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  ✓ Celda $ID agregada exitosamente"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "PID: $CELDA_PID"
    echo "Posición: $POS"
    echo ""
    echo "La celda está ahora capturando piezas."
    echo ""
    echo "Para detener esta celda:"
    echo "  kill $CELDA_PID"
    echo ""
    echo "Para ver todas las celdas:"
    echo "  ps aux | grep celda"
    echo ""
else
    echo ""
    echo "❌ Error: La celda no se pudo iniciar"
    echo "   Revisa los mensajes de error arriba."
    exit 1
fi