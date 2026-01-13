#!/bin/bash
# init_git.sh - Inicializar repositorio Git para el proyecto

echo "════════════════════════════════════════════════════════"
echo "  Inicializando Repositorio Git - LEGO Master"
echo "════════════════════════════════════════════════════════"
echo ""

# Verificar si Git está instalado
if ! command -v git &> /dev/null; then
    echo "Error: Git no está instalado"
    echo "Instalar con: sudo apt install git"
    exit 1
fi

# Inicializar repositorio si no existe
if [ ! -d ".git" ]; then
    echo "1. Inicializando repositorio Git..."
    git init
    echo "   ✓ Repositorio inicializado"
else
    echo "1. Repositorio Git ya existe"
fi

# Configurar usuario si no está configurado
if [ -z "$(git config user.name)" ]; then
    echo ""
    read -p "   Ingresa tu nombre para Git: " git_name
    git config user.name "$git_name"
    echo "   ✓ Nombre configurado: $git_name"
fi

if [ -z "$(git config user.email)" ]; then
    echo ""
    read -p "   Ingresa tu email para Git: " git_email
    git config user.email "$git_email"
    echo "   ✓ Email configurado: $git_email"
fi

# Crear .gitignore si no existe
if [ ! -f ".gitignore" ]; then
    echo ""
    echo "2. Creando .gitignore..."
    cat > .gitignore << 'EOF'
# Ejecutables
bin/
*.o
*.out
*.exe

# Logs
logs/
*.log

# Editor/IDE
.vscode/
.idea/
*.swp
*~
.DS_Store

# Backup
*~
*.bak
*.backup

# Temporal
tmp/
temp/
EOF
    echo "   ✓ .gitignore creado"
else
    echo ""
    echo "2. .gitignore ya existe"
fi

# Hacer primer commit
echo ""
echo "3. Preparando primer commit (Día 1)..."

git add README.md Makefile .gitignore 2>/dev/null
git add src/common.h src/banda.c 2>/dev/null
git add scripts/*.sh 2>/dev/null

if git diff --cached --quiet; then
    echo "   ⚠ No hay cambios para commitear"
else
    git commit -m "Día 1: Estructura base del proyecto

- Implementada banda transportadora con arreglo circular
- Sistema de memoria compartida (IPC)
- Semáforos para sincronización
- Makefile con targets básicos
- Scripts de setup y limpieza
- Documentación inicial"
    echo "   ✓ Commit realizado"
fi

# Mostrar estado
echo ""
echo "4. Estado del repositorio:"
git status --short

# Mostrar log
echo ""
echo "5. Historial de commits:"
git log --oneline --all --graph --decorate || echo "   (Sin commits aún)"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✓ Repositorio Git Configurado"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Comandos útiles de Git:"
echo "  git status              - Ver estado actual"
echo "  git add <archivo>       - Agregar archivo al stage"
echo "  git commit -m 'msg'     - Hacer commit"
echo "  git log --oneline       - Ver historial"
echo "  git diff                - Ver cambios no commiteados"
echo ""
echo "Para cada día del proyecto:"
echo "  git add ."
echo "  git commit -m 'Día X: Descripción'"
echo ""
echo "════════════════════════════════════════════════════════"