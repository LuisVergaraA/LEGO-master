# LEGO Master - Sistema de Empaquetado Automatizado

## Descripción
Sistema de simulación de empaquetado de bloques tipo LEGO usando procesos concurrentes, memoria compartida y semáforos en C (Linux/WSL).

## Arquitectura del Sistema

### Componentes Principales:
1. **Dispensadores** - Generan piezas aleatorias en la banda
2. **Banda Transportadora** - Arreglo circular que mueve las piezas
3. **Celdas de Empaquetado** - 4 brazos robóticos que ensamblan cajas
4. **Monitor** - Visualización en tiempo real del sistema

### Características:
- Memoria compartida (System V IPC)
- Sincronización con semáforos
- Procesos independientes y dinámicos
- Balance de carga entre brazos robóticos
- Validación de cajas completas

## Estructura del Proyecto

```
lego-master/
├── src/
│   ├── common.h           # Estructuras y constantes compartidas
│   ├── dispensadores.c    # Proceso generador de piezas
│   ├── banda.c           # Proceso banda transportadora
│   ├── celda.c           # Proceso celda de empaquetado
│   └── monitor.c         # Proceso de visualización
├── scripts/
│   ├── setup.sh          # Inicialización del sistema
│   ├── test_basico.sh    # Prueba básica
│   └── cleanup.sh        # Limpieza de recursos IPC
├── Makefile
└── README.md
```

## Compilación

```bash
make all
```

## Ejecución

### Sistema Completo (Día 2)

#### Opción 1: Script Automático (Recomendado)
```bash
./scripts/test_dia2.sh
```

#### Opción 2: Manual (3 terminales)

**Terminal 1 - Banda transportadora:**
```bash
./bin/banda 50 100
# Parámetros: <tamaño> <velocidad_ms>
```

**Terminal 2 - Monitor (opcional pero recomendado):**
```bash
./bin/monitor
```

**Terminal 3 - Dispensadores:**
```bash
./bin/dispensadores 4 3 3 2 4 1 50000
# Parámetros: <#dispensadores> <#sets> <pzA> <pzB> <pzC> <pzD> <intervalo_us>
```

### Ejemplos de Configuración

```bash
# Configuración pequeña (rápida)
./bin/dispensadores 2 2 2 2 2 2 30000

# Configuración normal
./bin/dispensadores 4 3 3 2 4 1 50000

# Configuración grande
./bin/dispensadores 6 10 4 3 5 2 100000
```

## Configuración del Sistema

### Keys IPC:
- `2222` - Memoria compartida de la banda
- `2223` - Semáforos de la banda
- `2224` - Memoria compartida de estadísticas

### Tipos de Piezas:
- `0` - Espacio vacío
- `1` - Pieza tipo A
- `2` - Pieza tipo B
- `3` - Pieza tipo C
- `4` - Pieza tipo D

## Progreso del Proyecto

### ✅ Día 1 - Completado
- Estructura del proyecto
- common.h con definiciones compartidas
- banda.c - Banda transportadora con arreglo circular
- Makefile para compilación
- Scripts de inicialización

### ✅ Día 2 - Completado
- dispensadores.c - Sistema generador de piezas
- monitor.c - Visualización en tiempo real con colores
- Estadísticas del sistema
- Integración completa banda ↔ dispensadores
- Script de prueba automática

### ⏳ Próximos Pasos
- Día 3: Celdas con brazos robóticos
- Día 4: Balance y validación
- Día 5: Robustez y celdas dinámicas

## Limpieza del Sistema

```bash
# Limpiar recursos IPC manualmente
ipcs -m | grep 2222 | awk '{print $2}' | xargs -n1 ipcrm -m
ipcs -s | grep 2223 | awk '{print $2}' | xargs -n1 ipcrm -s

# O usar el script
./scripts/cleanup.sh
```

## Requisitos
- GCC
- Linux/WSL
- System V IPC support

## Autor
Luis Vergara Arellano