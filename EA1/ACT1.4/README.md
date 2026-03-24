# Actividad 4: Medición de Impacto de Plantillas de CI/CD en el Negocio

Esta actividad representa la fase final del laboratorio. Aquí, dejarás de actuar solo como desarrollador/DevOps para adoptar una visión de **Arquitecto de Soluciones**, analizando métricas reales para justificar la inversión en la estandarización y optimización de pipelines.

El objetivo es pasar de la implementación técnica ("funciona") a la justificación de negocio ("aporta valor").

---

# 📌 **Índice**

1.  Objetivos de la Actividad
2.  Definición de Escenarios de Prueba
3.  Paso 1: Recopilación de Métricas (Ejecución)
4.  Paso 2: Análisis de Eficiencia y Costos (Cálculo)
5.  Paso 3: Informe Ejecutivo (Entregable Final)

---

# 🧩 Pre-requisitos

Antes de comenzar, asegúrate de contar con:

-   Un sistema basado en Debian/Ubuntu.
-   Docker instalado en tu máquina.
-   Credenciales de AWS para laboratorio o cuenta propia.
-   GitHub repository donde configuraremos el pipeline.
-   Node Version Manager (nvm) para gestionar versiones de Node.js.

## 1. 🎯 Objetivos de la Actividad

1.  **Ejecutar pruebas comparativas** entre el flujo manual, el pipeline básico y el pipeline optimizado con caché.
2.  **Recopilar métricas clave** (tiempo de ejecución, frecuencia de fallos, intervención humana).
3.  **Redactar un informe de impacto** que traduzca mejoras técnicas en valor de negocio (Time-to-Market y Reducción de Costos).

---

## 2. ⚙️ Definición de Escenarios de Prueba

Para realizar esta medición, analizaremos tres escenarios basados en el trabajo realizado en las guías A, B y C:

* **Escenario A (Línea Base - Manual):** Ejecución de comandos en terminal local (basado en `README-A`). Requiere atención constante.
* **Escenario B (Automatización Básica - Cache Miss):** Primera ejecución del pipeline en GitHub Actions o ejecución tras borrar la caché (basado en `README-B` / primera vez de `README-C`).
* **Escenario C (Optimización - Cache Hit):** Segunda ejecución del pipeline optimizado, aprovechando la caché de NPM y Docker Layers (basado en `README-C`).

---

## 3. ⏱️ Paso 1: Recopilación de Métricas

**Instrucciones:** Completa la tabla de resultados ejecutando los flujos correspondientes.

### 3.1. Medición del Escenario Manual (Simulación Local)
Ejecuta localmente los siguientes comandos secuenciales.
* **Cronometra:** Desde que escribes el primer comando hasta que la imagen aparece en AWS ECR.
* **Factor Humano:** Incluye el tiempo que tardas en escribir los comandos y esperar a que uno termine para lanzar el siguiente.

Ejecuta las actividades de instlación del archivo README.md de la ACT1.1 para poder realizar la configuración manual.

### 3.2. Medición del Escenario Automatizado (Sin Caché)
1. Ve a tu repositorio en GitHub > pestaña **Actions**.
2. En la barra lateral izquierda, busca la opción **"Caches"** y borra las cachés existentes si las hay (para forzar un *Cache Miss*).
3. Dispara el workflow manualmente.
4. Registra el tiempo total de "Duration" en la tabla.

### 3.3. Medición del Escenario Optimizado (Con Caché)
1. Inmediatamente después de que termine el escenario anterior, vuelve a disparar el **mismo** workflow (**Re-run jobs**).
2. Observa cómo los pasos **Setup Node**, **Install Dependencies** y **Docker Build** muestran un **Cache Hit**.
3. Registra el nuevo tiempo total.

### 📊 Tabla de Resultados (A completar por el estudiante)

Si quieres revisar algunas métricas, puedes visualizar las de Github Actions en la sección [Metricas](https://docs.github.com/en/actions/concepts/metrics).

| Métrica | Escenario A: Manual (Local) | Escenario B: CI Básico (Cache Miss) | Escenario C: CI Optimizado (Cache Hit) |
| :--- | :---: | :---: | :---: |
| **Tiempo de Setup/Install** | _(ej. 45s)_ | _(ej. 30s)_ | **_(ej. 2s)_** |
| **Tiempo de Pruebas** | _(ej. 20s)_ | _(ej. 15s)_ | _(ej. 15s)_ |
| **Tiempo Build & Push** | _(ej. 120s)_ | _(ej. 90s)_ | **_(ej. 15s)_** |
| **Intervención Humana** | 100% (Atención total) | 0% (Disparo automático) | 0% |
| **Riesgo de Error** | Alto (Olvido de tests) | Medio | Nulo (Validado por Gate) |
| **Tiempo Total (aprox)** | **~ X min** | **~ Y min** | **~ Z min** |

---

## 4. 📉 Paso 2: Análisis de Eficiencia y Costos

Responde a las siguientes preguntas basándote en tus datos recolectados:

1. **Cálculo de Ahorro de Tiempo:**
    * Si un equipo de 10 desarrolladores realiza 5 despliegues al día cada uno (Total: 50 despliegues diarios).
    * ¿Cuánto tiempo se ahorra al día usando el **Escenario C** vs el **Escenario A**?
    * *Fórmula:* (Tiempo A - Tiempo C) multiplicado por 50 es igual al Tiempo Ahorrado Diario.

2. **Impacto en Costos de Nube (GitHub Actions):**
    * Calcula el porcentaje de reducción de tiempo entre el **Escenario B** (Cache Miss) y el **Escenario C** (Cache Hit).
    * *Fórmula:* ((Tiempo B - Tiempo C) dividido por Tiempo B) multiplicado por 100 es igual al % Ahorro de Costos.

3. **Análisis de Fiabilidad (Quality Gate):**
    * En el **Escenario A**, explica qué falla si olvidas ejecutar las pruebas antes de subir la imagen.
    * En el **Escenario C**, explica cómo el **"Gate"** (la dependencia de la etapa de Contenerización a la etapa de Validación) impide que una imagen defectuosa llegue a ECR.

---

## 5. 📝 Paso 3: Informe Ejecutivo (Entregable Final)

Redacta un breve informe (máximo 1 página) dirigido a un "Gerente de Tecnología" o "Cliente", explicando por qué la empresa debe adoptar esta plantilla optimizada.

> ### 📄 Informe de Estandarización y Optimización de CI/CD
>
> **Resumen Ejecutivo:**
> Hemos completado la transición de despliegues manuales a un pipeline automatizado y optimizado para el proyecto [Nombre del Proyecto].
>
> **Hallazgos Clave:**
> 1. **Aceleración del Time-to-Market:** Hemos reducido el tiempo de ciclo de despliegue en un **[Insertar %]** comparando el proceso manual contra el automatizado.
> 2. **Eficiencia Operativa:** Gracias a la implementación de caché, redujimos el consumo de recursos de computación en un **[Insertar %]** por ejecución, optimizando el presupuesto.
> 3. **Garantía de Calidad:** Se eliminó el riesgo de error humano. Ninguna imagen llega a ECR sin pasar por validación de seguridad (npm audit) y pruebas (npm test).
>
> **Conclusión:**
> La adopción de estas plantillas estandarizadas permite escalar el equipo de desarrollo sin sacrificar la estabilidad del software ni aumentar linealmente los costos.