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

#### Opción 1: Script Automático (Recomendado)
```bash
./scripts/demo_profesor.sh
```

#### Opción 2: Manual (4 terminales)

**Terminal 1 - Banda transportadora:**
```bash
./bin/banda 60 200 &
sleep 2
# Parámetros: <tamaño> <velocidad_ms>
```

**Terminal 2: Celda 1:**
```bash
./bin/celda 1 15 3 2 4 1
```

**Terminal 3: Celda 2:**
./bin/celda 2 40 3 2 4 1

**Terminal 4: Dispensadores:**
```bash
./bin/dispensadores 6 5 3 2 4 1 100000
# Parámetros: <#dispensadores> <#sets> <pzA> <pzB> <pzC> <pzD> <intervalo_us>
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

### 100% listo 

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