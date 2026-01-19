# LEGO Master - Sistema de Empaquetado Automatizado

**Autor:** Luis Vergara Arellano  
**Proyecto:** Sistemas Operativos - Proyecto Final 2025  
**Descripción:** Simulación de línea de empaquetado de bloques LEGO usando concurrencia en C/Linux

[![Compilación](https://img.shields.io/badge/build-passing-brightgreen)]()
[![Lenguaje](https://img.shields.io/badge/C-11-orange)]()

---

## 📋 Descripción

Sistema de simulación que implementa una línea de empaquetado automatizada con las siguientes características:

- **Banda transportadora circular** con múltiples piezas por posición
- **Dispensadores** con generación aleatoria de piezas
- **Celdas de empaquetado** con 4 brazos robóticos cada una
- **Balance automático** de carga entre brazos
- **Validación** de cajas por operador simulado
- **Sincronización robusta** sin race conditions
- **Celdas dinámicas** (agregar/quitar en runtime)

---

## 🎯 Características Implementadas

### ✅ Requisitos del proyecto Cumplidos

- [x] Banda transportadora con arreglo circular
- [x] Múltiples piezas por posición en la banda
- [x] Dispensadores con generación aleatoria
- [x] Celdas con 4 brazos robóticos (threads)
- [x] **Restricción:** Solo 2 brazos retiran simultáneamente
- [x] **Restricción:** Solo 1 brazo deposita a la vez
- [x] **Balance:** Cada Y piezas dispensadas, brazo más ocupado se suspende Δt2 segundos
- [x] Validación de cajas por operador (delay aleatorio 0-Δt1)
- [x] Reporte de cajas OK/FAIL
- [x] Reporte de piezas sobrantes por tipo
- [x] Celdas dinámicas (agregar/quitar en runtime)
- [x] Programación defensiva
- [x] Manejo robusto de señales y recursos IPC

### 🔧 Aspectos de Ingeniería

- [x] Uso eficiente de memoria compartida (System V IPC)
- [x] Sincronización con semáforos y mutex POSIX
- [x] Procesos independientes comunicándose via IPC
- [x] Threads (pthreads) para brazos robóticos
- [x] Manejo correcto de condiciones de carrera
- [x] Sin deadlocks ni starvation
- [x] Código documentado y bien estructurado
- [x] **Captura atómica** para prevenir race conditions
- [x] **Balance basado en piezas dispensadas** (según PDF)

---

## 🚀 Inicio Rápido

### Para el Profesor

**Opción 1: Demostración Completa (8 minutos)** 
```bash
make all
make test-validacion
```

**Opción 2: Validación Express (5 minutos)**
```bash
make all
make test-rapido
```

Estos comandos:
- ✅ Compilan el proyecto
- ✅ Limpian recursos IPC previos
- ✅ Ejecutan el sistema automáticamente
- ✅ Muestran validación de requisitos del PDF
- ✅ Generan reporte detallado
- ✅ Limpian recursos al finalizar

### Para Usuarios Regulares

```bash
# Compilar
make all

# Ejecutar demostración
make test

# Ver todos los comandos
make help
```

---

## 📦 Requisitos

- **Sistema Operativo:** Linux / WSL
- **Compilador:** GCC con soporte C11
- **Bibliotecas:** 
  - pthread
  - System V IPC (memoria compartida y semáforos)
- **Herramientas:** make

### Verificar Requisitos

```bash
make check-system
```

---

## 🏗️ Arquitectura

```
┌──────────────┐
│Dispensadores │──┐ (Generación aleatoria)
└──────────────┘  │ 
                  ▼
         ┌─────────────────┐
         │     Banda       │ (Circular, múltiples piezas/posición)
         │ Transportadora  │
         └────┬────┬───────┘
              │    │
       ┌──────▼─┐  └──────▼─┐
       │ Celda 1│    │ Celda N│
       │ 4 Brazos│    │ 4 Brazos│ (Max 2 retiran, 1 deposita)
       └────┬───┘    └────┬───┘
            │             │
       [Caja OK]     [Caja OK]
            │             │
        Validación    Validación (0-2s aleatorio)
```

### Componentes

1. **`banda.c`** - Proceso de banda transportadora
   - Mueve piezas de posición 0 a N-1 (circular)
   - Maneja memoria compartida central
   - Registra piezas que caen al tacho

2. **`dispensadores.c`** - Proceso generador de piezas
   - Dispensa piezas aleatorias en posición 0
   - Controla cantidad total de piezas
   - Actualiza estadísticas globales

3. **`celda.c`** - Proceso + 4 threads (brazos)
   - Captura piezas de la banda (atómicamente)
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

---

## 🔧 Compilación

```bash
# Compilar todo
make all

# Compilar componentes individuales
make banda
make dispensadores
make celda
make monitor

# Ver ayuda completa
make help
```

---

## 🎮 Ejecución

### Opción 1: Scripts Automáticos (Recomendado)

#### **Demostración Rápida**
```bash
make test-rapido
```
- Duración: ~5 minutos
- Muestra todos los requisitos del PDF
- Genera reporte automático

#### **Validación Completa**
```bash
make test-validacion
```
- Duración: ~8 minutos
- Explicación detallada de cada requisito
- Análisis completo de cumplimiento
- Respuestas a las 5 preguntas del PDF

### Opción 2: Ejecución Manual

Necesitas **4 terminales** para ejecutar manualmente:

**Terminal 1 - Banda:**
```bash
./bin/banda 60 200 &
# Parámetros: <tamaño> <velocidad_ms>
# Ejemplo: 60 pasos, 200ms por paso
```

**Terminal 2 - Dispensadores:**
```bash
./bin/dispensadores 6 5 3 2 4 1 100000 &
# Parámetros: <#disp> <#sets> <pzA> <pzB> <pzC> <pzD> <intervalo_us>
# 6 dispensadores, 5 sets, intervalo 100ms
```

**Terminal 3 - Celda 1:**
```bash
./bin/celda 1 15 3 2 4 1 &
# Parámetros: <id> <posición> <pzA> <pzB> <pzC> <pzD>
# id=1, pos=15, SET: A=3, B=2, C=4, D=1
```

**Terminal 4 - Celda 2:**
```bash
./bin/celda 2 40 3 2 4 1 &
# id=2, pos=40, mismo SET
```

**Terminal 5 (Opcional) - Monitor:**
```bash
./bin/monitor
# Visualización en tiempo real
```

---

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

---

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
   Cajas con errores: 0
   Total piezas procesadas: 40
   Tasa de éxito: 100.0%

🤖 ESTADÍSTICAS POR BRAZO:
   Brazo 0: 11 piezas (27.5%)
   Brazo 1: 10 piezas (25.0%)
   Brazo 2: 10 piezas (25.0%)
   Brazo 3: 9 piezas (22.5%)

⚖️  BALANCE DE CARGA:
   Promedio: 10.0 | Min: 9 | Max: 11 | Diff: 2
   Desbalance: 20.0% ✓ Bueno
```

### Verificar Balance Automático

```bash
# Ver suspensiones de brazos por balance
make check-balance

# O manualmente
grep "💤 Suspendido" /tmp/*celda*.log
```

Deberías ver líneas como:
```
[BRAZO 2] 💤 Suspendido por balance (12 piezas procesadas, checkpoint: 16)
[BRAZO 2] ✅ Reactivado después de suspensión
```

---

## 🛠️ Resolución de Problemas

### "Error: shmget banda"
```bash
# Limpiar recursos IPC
make clean-ipc

# O manualmente
ipcrm -a
```
---

## 🧪 Pruebas y Verificación

### Verificar Sistema
```bash
# Estado general
make check-system

# Recursos IPC
make check-ipc

# Logs disponibles
make check-logs

# Balance automático
make check-balance
```

### Pruebas Rápidas

```bash
# Demo express (5 min)
make test-rapido

# Validación completa (8 min)
make test-validacion

# Prueba estándar
make test
```

---

## 🧹 Limpieza

```bash
# Eliminar ejecutables
make clean

# Limpiar recursos IPC
make clean-ipc

# Eliminar logs
make clean-logs

# Limpieza completa
make distclean
```

---

## 📚 Documentación

### Documentos Disponibles

- **`README.md`** (este archivo) - Guía general del proyecto
- **`src/common.h`** - Código comentado de estructuras y funciones
- **Comentarios en código** - Cada archivo incluye documentación inline

### Ver Documentación de Código

```bash
# Ver funciones principales
grep -n "^void\|^int" src/*.c

# Ver estructuras de datos
grep -A 10 "typedef struct" src/common.h
```
---

## 📝 Notas Importantes

1. **Ejecutar banda primero:** Los demás componentes dependen de ella
2. **Posiciones de celdas:** No muy cerca del final ni entre sí
3. **Limpieza IPC:** Siempre limpiar antes de nueva ejecución con `make clean-ipc`
4. **Señales:** Ctrl+C limpia recursos automáticamente
5. **Balance:** Basado en piezas dispensadas globalmente (no por celda)
6. **Captura:** Operación atómica previene duplicación de piezas

---

## 🎯 Respuestas a las 5 Preguntas del PDF

### 1. ¿Cómo represento las partes del SET?
Array `piezas_requeridas[4]` en `ConfiguracionSET` con mapeo directo índice→tipo.

### 2. ¿Cómo planteo la sincronización?
- **Captura:** Mutex para operación atómica buscar+retirar
- **Retiro:** Semáforo con valor 2
- **Depósito:** Mutex exclusivo
- **Validación:** Triple verificación

### 3. ¿Cómo minimizo tiempo para balance?
Array estático con scan O(1), solo en checkpoints cada Y piezas.

### 4. ¿Condiciones para X cajas correctas?
Total exacto de piezas, banda lenta, distribución uniforme, triple verificación.

### 5. ¿Diseño robusto para celdas dinámicas?
Registro/desregistro en memoria compartida, IPC con keys fijas, cleanup handlers.

Ver **`DISEÑO.md`** para respuestas detalladas.

---

## 📧 Autor

**Luis Vergara Arellano**  
Proyecto Final - Sistemas Operativos 2025

---

## 🎉 ¡Gracias por revisar este proyecto!

Para comenzar:
```bash
make all
make test-rapido
```

Para más ayuda:
```bash
make help
```
