#!/bin/bash
# setup.sh - Script de inicialización del proyecto LEGO Master

echo "════════════════════════════════════════════════════════"
echo "  LEGO Master - Configuración Inicial"
echo "════════════════════════════════════════════════════════"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "Makefile" ]; then
    echo "Error: Ejecutar desde el directorio raíz del proyecto"
    exit 1
fi

# Crear estructura de directorios
echo "1. Creando estructura de directorios..."
mkdir -p src bin scripts logs
echo "   ✓ Directorios creados"

# Verificar existencia de archivos fuente
echo ""
echo "2. Verificando archivos fuente..."
files_to_check=("src/common.h" "src/banda.c")
missing=0

for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file (falta)"
        missing=1
    fi
done

if [ $missing -eq 1 ]; then
    echo ""
    echo "⚠ Faltan archivos. Asegúrate de tener todos los archivos del Día 1."
fi

# Limpiar recursos IPC previos
echo ""
echo "3. Limpiando recursos IPC anteriores..."
ipcs -m | grep $(id -u) | grep 2222 | awk '{print $2}' | xargs -r -n1 ipcrm -m 2>/dev/null || true
ipcs -m | grep $(id -u) | grep 2224 | awk '{print $2}' | xargs -r -n1 ipcrm -m 2>/dev/null || true
ipcs -s | grep $(id -u) | grep 2223 | awk '{print $2}' | xargs -r -n1 ipcrm -s 2>/dev/null || true
ipcs -s | grep $(id -u) | grep 2225 | awk '{print $2}' | xargs -r -n1 ipcrm -s 2>/dev/null || true
echo "   ✓ Recursos IPC limpiados"

# Compilar proyecto
echo ""
echo "4. Compilando proyecto..."
make clean > /dev/null 2>&1
if make all; then
    echo "   ✓ Compilación exitosa"
else
    echo "   ✗ Error en compilación"
    exit 1
fi

# Verificar ejecutables
echo ""
echo "5. Verificando ejecutables..."
if [ -f "bin/banda" ]; then
    echo "   ✓ bin/banda"
else
    echo "   ✗ bin/banda no generado"
fi

# Crear scripts auxiliares
echo ""
echo "6. Creando scripts auxiliares..."

# Script de limpieza
cat > scripts/cleanup.sh << 'EOF'
#!/bin/bash
echo "Limpiando recursos IPC del proyecto LEGO Master..."
ipcs -m | grep $(id -u) | awk '{print $2}' | xargs -r -n1 ipcrm -m 2>/dev/null || true
ipcs -s | grep $(id -u) | awk '{print $2}' | xargs -r -n1 ipcrm -s 2>/dev/null || true
echo "✓ Recursos limpiados"
EOF
chmod +x scripts/cleanup.sh
echo "   ✓ scripts/cleanup.sh"

# Script de prueba básica
cat > scripts/test_basico.sh << 'EOF'
#!/bin/bash
echo "=== Prueba Básica - Día 1 ==="
echo "Iniciando banda transportadora..."
echo "Presiona Ctrl+C para detener"
echo ""
./bin/banda 40 150
EOF
chmod +x scripts/test_basico.sh
echo "   ✓ scripts/test_basico.sh"

# Crear .gitignore
cat > .gitignore << 'EOF'
# Ejecutables
bin/
*.o
*.out

# Logs
logs/
*.log

# Editor/IDE
.vscode/
.idea/
*.swp
*~

# Sistema
.DS_Store
EOF
echo "   ✓ .gitignore"

# Resumen final
echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✓ Configuración Completada"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Próximos pasos:"
echo ""
echo "1. Probar la banda transportadora:"
echo "   ./bin/banda 50 100"
echo ""
echo "2. O usar el script de prueba:"
echo "   ./scripts/test_basico.sh"
echo ""
echo "3. Ver ayuda del Makefile:"
echo "   make help"
echo ""
echo "4. Limpiar recursos IPC si es necesario:"
echo "   make clean-ipc"
echo "   # o"
echo "   ./scripts/cleanup.sh"
echo ""
echo "════════════════════════════════════════════════════════"