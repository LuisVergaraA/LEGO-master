# LEGO Master - Sistema de Empaquetado Automatizado

**Autor:** Luis Vergara Arellano  
**Proyecto:** Sistemas Operativos - Proyecto Final 2025  
**Descripción:** Simulación de línea de empaquetado de bloques LEGO usando concurrencia en C/Linux

---

## 📋 Descripción

Sistema de simulación que implementa una línea de empaquetado automatizada con las siguientes características:

- **Banda transportadora circular** con múltiples piezas por posición
- **Dispensadores** con generación aleatoria de piezas
- **Celdas de empaquetado** con 4 brazos robóticos cada una
- **Balance automático** de carga entre brazos
- **Validación** de cajas por operador simulado
- **Celdas dinámicas** (agregar/quitar en runtime)

## 🎯 Características Implementadas

### Requisitos del PDF ✅

- [x] Banda transportadora con arreglo circular
- [x] Múltiples piezas por posición en la banda
- [x] Dispensadores con generación aleatoria
- [x] Celdas con 4 brazos robóticos (threads)
- [x] **Restricción:** Solo 2 brazos retiran simultáneamente
- [x] **Restricción:** Solo 1 brazo deposita a la vez
- [x] **Balance:** Cada Y piezas, brazo más ocupado se suspende Δt2 segundos
- [x] Validación de cajas por operador (delay aleatorio 0-Δt1)
- [x] Reporte de cajas OK/FAIL
- [x] Reporte de piezas sobrantes por tipo
- [x] Celdas dinámicas (agregar/quitar en runtime)
- [x] Programación defensiva
- [x] Manejo robusto de señales y recursos IPC

### Aspectos de Ingeniería

- [x] Uso eficiente de memoria compartida (System V IPC)
- [x] Sincronización con semáforos y mutex POSIX
- [x] Procesos independientes comunicándose via IPC
- [x] Threads (pthreads) para brazos robóticos
- [x] Manejo correcto de condiciones de carrera
- [x] Sin deadlocks ni starvation
- [x] Código documentado y bien estructurado

## 🏗️ Arquitectura

```
┌──────────────┐
│Dispensadores │──┐
└──────────────┘  │ Piezas
                  ▼
         ┌─────────────────┐
         │     Banda       │
         │ Transportadora  │
         └────┬────┬───────┘
              │    │
       ┌──────▼─┐  └──────▼─┐
       │ Celda 1│    │ Celda N│
       │ 4 Brazos│    │ 4 Brazos│
       └────┬───┘    └────┬───┘
            │             │
       [Caja OK]     [Caja OK]
```

### Componentes

1. **`banda.c`** - Proceso de banda transportadora
   - Mueve piezas de posición 0 a N-1
   - Maneja memoria compartida central
   - Registra piezas que caen al tacho

2. **`dispensadores.c`** - Proceso generador de piezas
   - Dispensa piezas aleatorias en posición 0
   - Controla cantidad total de piezas
   - Actualiza estadísticas globales

3. **`celda.c`** - Proceso + 4 threads (brazos)
   - Captura piezas de la banda
   - Ensambla cajas según SET configurado
   - Implementa balance automático de brazos
   - Valida cajas completas

4. **`monitor.c`** - Visualización en tiempo real (opcional)
   - Muestra estado de la banda
   - Estadísticas del sistema
   - Colores ANSI para mejor visualización

5. **`common.h`** - Estructuras y funciones compartidas
   - Definiciones de constantes
   - Estructuras de datos
   - Operaciones de semáforos
   - Funciones auxiliares

## 📦 Requisitos

- **Sistema Operativo:** Linux / WSL
- **Compilador:** GCC con soporte C11
- **Bibliotecas:** 
  - pthread
  - System V IPC (memoria compartida y semáforos)
- **Herramientas:** make

## 🚀 Compilación

```bash
# Compilar todo
make all

# Compilar componentes individuales
make banda
make dispensadores
make celda
make monitor

# Ver ayuda
make help
```

## 🎮 Ejecución

### Opción 1: Script Automático (Recomendado)

```bash
# Prueba completa del sistema
./test_completo.sh

# O usando make
make test
```

Este script:
- Limpia recursos IPC previos
- Inicia todos los componentes
- Ejecuta la simulación
- Muestra reportes detallados
- Limpia recursos al finalizar

### Opción 2: Ejecución Manual

Necesitas **4 terminales** para ejecutar manualmente:

**Terminal 1 - Banda:**
```bash
./bin/banda 60 200 &
# Parámetros: <tamaño> <velocidad_ms>
# Ejemplo: 60 pasos, 200ms por paso
```

**Terminal 2 - Celda 1:**
```bash
./bin/celda 1 15 3 2 4 1 &
# Parámetros: <id> <posición> <pzA> <pzB> <pzC> <pzD>
# id=1, pos=15, SET: A=3, B=2, C=4, D=1
```

**Terminal 3 - Celda 2:**
```bash
./bin/celda 2 40 3 2 4 1 &
# id=2, pos=40, mismo SET
```

**Terminal 4 - Dispensadores:**
```bash
./bin/dispensadores 6 5 3 2 4 1 100000
# Parámetros: <#disp> <#sets> <pzA> <pzB> <pzC> <pzD> <intervalo_us>
# 6 dispensadores, 5 sets, intervalo 100ms
```

**Terminal 5 (Opcional) - Monitor:**
```bash
./bin/monitor
# Visualización en tiempo real
```

## 📊 Configuración de Parámetros

### Banda Transportadora
- **Tamaño:** 10-200 pasos
- **Velocidad:** 50-1000 ms/paso
- **Recomendado:** 60 pasos, 200ms

### Celdas
- **ID:** 1-10 (único por celda)
- **Posición:** 0 a (tamaño_banda - 10)
- **Piezas por SET:** 1-20 de cada tipo
- **Recomendado:** Distribuir cada 20-25 pasos

### Dispensadores
- **Cantidad:** 1-10 dispensadores
- **Sets:** 1-100 sets a producir
- **Intervalo:** 10000-1000000 microsegundos
- **Recomendado:** 6 dispensadores, 50000-100000 us

## 📈 Interpretación de Resultados

### Métricas Clave

**Producción:**
- **Cajas OK:** Cantidad de cajas correctamente ensambladas
- **Cajas FAIL:** Cajas con errores
- **Tasa de éxito:** `OK / (OK + FAIL) * 100`
  - ✅ Excelente: > 90%
  - ✓ Bueno: 80-90%
  - ⚠ Regular: 60-80%
  - ❌ Malo: < 60%

**Balance de Brazos:**
- **Desbalance:** `(max - min) / promedio * 100`
  - ✅ Excelente: < 10%
  - ✓ Bueno: 10-25%
  - ⚠ Regular: 25-50%
  - ❌ Malo: > 50%

**Eficiencia:**
- **Piezas al tacho:** Piezas no capturadas
  - ✅ < 10%: Excelente
  - ✓ 10-20%: Bueno
  - ⚠ 20-30%: Regular
  - ❌ > 30%: Malo

### Ejemplo de Salida

```
╔═══════════════════════════════════════════════════════════╗
║       RESUMEN FINAL - CELDA 1 (Posición 15)              ║
╚═══════════════════════════════════════════════════════════╝

⏱️  TIEMPO DE OPERACIÓN: 127 segundos (2.1 minutos)

📦 PRODUCCIÓN:
   Cajas completadas OK: 4
   Cajas con errores: 1
   Total piezas procesadas: 48
   Tasa de éxito: 80.0%

🤖 ESTADÍSTICAS POR BRAZO:
   Brazo 0: 13 piezas (27.1%)
   Brazo 1: 11 piezas (22.9%)
   Brazo 2: 12 piezas (25.0%)
   Brazo 3: 12 piezas (25.0%)

⚖️  BALANCE DE CARGA:
   Promedio: 12.0 | Min: 11 | Max: 13 | Diff: 2
   Desbalance: 16.7% ✓ Bueno
```

## 🛠️ Resolución de Problemas

### "Error: shmget banda"
```bash
# Limpiar recursos IPC
make clean-ipc

# O manualmente
ipcrm -a
```

### "Celda no captura piezas"
- Verificar que la banda esté ejecutándose primero
- Verificar que la posición no esté muy cerca del final
- Aumentar velocidad de banda (más ms/paso)

### "Muchas piezas al tacho"
- Reducir velocidad de banda (más lento)
- Agregar más celdas
- Distribuir celdas más uniformemente
- Aumentar número de dispensadores

### "Tasa de éxito baja (< 80%)"
- Verificar que haya suficientes piezas de cada tipo
- Reducir velocidad de banda
- Verificar que celdas estén en posiciones óptimas

## 🧪 Pruebas

### Prueba Completa
```bash
make test
# o
./test_completo.sh
```

### Prueba Rápida (2 sets)
```bash
make test-quick
```

### Verificar IPC
```bash
make check-ipc
```

## 🧹 Limpieza

```bash
# Eliminar ejecutables
make clean

# Limpiar recursos IPC
make clean-ipc

# Limpieza completa
make distclean
```

## 📚 Documentación Adicional

- **`DISEÑO.md`** - Documento de diseño detallado con respuestas a las 5 preguntas del PDF
- **`src/common.h`** - Código comentado de estructuras y funciones
- **Comentarios en código** - Cada archivo incluye documentación inline

## 🎓 Aspectos Educativos

Este proyecto demuestra:

1. **Concurrencia:**
   - Procesos independientes (fork)
   - Threads (pthreads)
   - Sincronización con semáforos y mutex

2. **IPC (Inter-Process Communication):**
   - Memoria compartida (System V)
   - Semáforos System V
   - Señales UNIX

3. **Sistemas Operativos:**
   - Manejo de recursos
   - Prevención de deadlocks
   - Condiciones de carrera
   - Programación defensiva

4. **Ingeniería de Software:**
   - Diseño modular
   - Reutilización de código
   - Manejo de errores
   - Documentación

## ⚠️ Consideraciones de Diseño

### Por qué estos parámetros?

- **Y = 4 piezas:** Balance frecuente sin overhead excesivo
- **Δt2 = 100ms:** Suficiente para que otros brazos actúen
- **Max 2 retiran:** Simula limitación física de espacio
- **1 deposita:** Evita condiciones de carrera en caja

### Garantías del Sistema

✅ **Sin deadlocks:** Orden consistente de locks  
✅ **Sin starvation:** Semáforos FIFO  
✅ **Sin race conditions:** Triple validación  
✅ **Liberación de recursos:** Handlers de señales  

## 📝 Notas Importantes

1. **Ejecutar banda primero:** Los demás componentes dependen de ella
2. **Posiciones de celdas:** No muy cerca del final ni entre sí
3. **Limpieza IPC:** Siempre limpiar antes de nueva ejecución
4. **Señales:** Ctrl+C limpia recursos automáticamente

## 🤝 Contribuciones

Este es un proyecto académico individual. El código está disponible para referencia educativa.

## Requisitos
- GCC
- Linux/WSL
- System V IPC support

## Autor
Luis Vergara Arellano