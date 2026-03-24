# Informe Técnico: Selección de Estrategia de Despliegue Continuo (EKS)

Para capturar la información, puedes volver a ejecutar los pasos de la Guía ACT2.2, y volver a capturar los tiempos y analizar con mas calma el comportamiento de cada estrategia.

# 📌 **Índice del Informe Técnico**

1.  Definición del Caso Práctico (Contexto)
    * 1.1. Aplicación y Descripción
    * 1.2. Restricciones Clave (Técnica, Legal/Compliance, Negocio)
2.  Evaluación de Estrategias y Criterios
    * 2.1. Criterios de Ponderación (Disponibilidad, Costo, Rollback, Exposición)
    * 2.2. Matriz de Evaluación (Puntuación de 1 a 5)
3.  Estrategia Seleccionada y Justificación
    * 3.1. Justificación Técnica (Manejo de Restricción Crítica y Rollback)
    * 3.2. Impacto en Continuidad Operativa y Agilidad
4.  Análisis de Métricas y Conclusiones (Opcional: Incluir la tabla comparativa de tiempos)

---

# 🛠️ **Pre-requisitos para la Elaboración del Informe**

Para completar el presente informe, se requiere la siguiente información y contexto:

* **Resultados de la Guía ACT2.2 Completados:** Se debe haber ejecutado previamente la "Guía de Despliegue Continuo en AWS EKS" y contar con un clúster de Kubernetes activo y configurado.
* **Métricas de Despliegue Capturadas:** Es fundamental disponer de los tiempos medidos (en segundos) para el **Rollout**, **Downtime**, **Propagación del Load Balancer** y **Switch de Servicio** para las cuatro estrategias analizadas (Rolling Update, All-in-Once, Canary y Blue/Green).
* **Definición del Caso de Negocio:** La información de los *placeholders* en la Sección 1 (`Aplicación` y `Restricciones Clave`) debe estar claramente definida para poder ponderar los criterios de evaluación.


## 1. Definición del Caso Práctico (Contexto)

**Aplicación:** [Nombre y descripción breve de la aplicación (Ej: Plataforma de e-commerce de alto tráfico, Microservicio de autenticación, Blog corporativo).]

**Restricciones Clave:**

- Técnica: [Ej: La base de datos no soporta retrocompatibilidad (rollback difícil), el boot time del Pod es de 3 minutos (despliegue lento).]

- Legal / Compliance: [Ej: Requisito de mantener el 99.99% de uptime (cuatro nueves), las auditorías exigen un rollback instantáneo.]

- Negocio: [Ej: La prioridad es el costo mínimo, la prioridad es la experiencia de usuario (cero interrupciones).]

## 2. Evaluación de Estrategias y Criterios

### Criterios de Ponderación
| Criterio | Ponderación (1-5) | Justificación |
| :--- | :--- | :--- |
| **Disponibilidad / Uptime** (Tasa de fallo) | [4 o 5] | [Ej: Alto impacto económico en caso de caída.] |
| **Costo Operativo** (Infraestructura extra) | [1 a 5] | [Ej: El costo es secundario a la estabilidad.] |
| **Velocidad de Rollback** | [4 o 5] | [Ej: Necesidad de revertir cambios en segundos.] |
| **Tasa de Exposición al Bug** | [1 a 5] | [Ej: ¿Cuántos usuarios ven el fallo antes de revertir?] |


### Matriz de Evaluación (Puntuación de 1 a 5 para cada estrategia)
| Estrategia | Disponibilidad | Costo | Rollback Rápido | Exposición al Bug | Puntuación Total |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Rolling Update** | | | | | |
| **Canary** | | | | | |
| **Blue/Green** | | | | | |

## 3. Estrategia Seleccionada y Justificación

Estrategia Seleccionada: [Indicar si es Rolling Update, Canary o Blue/Green]

### 3.1. Justificación Técnica

Motivo Principal: [Explicar por qué esta estrategia maneja mejor la restricción técnica crítica (Ej: Canary permite probar el bug de 2 minutos sin afectar al 95% de los usuarios).]

Manejo de Rollback: [Describir cómo se ejecutaría el rollback (Ej: En Blue/Green, es un simple cambio de selector en el Service).]

### 3.2. Impacto en Continuidad Operativa y Agilidad

Continuidad Operativa (Uptime/Estabilidad): [Explicar cómo la estrategia asegura la estabilidad (Ej: Blue/Green garantiza cero interrupciones ya que el switch es a nivel de Service).]

Agilidad del Negocio (Velocidad de Entrega): [Explicar si la estrategia ralentiza o acelera el ciclo de desarrollo (Ej: Canary es ágil ya que permite el monitoreo automatizado y rápido de nuevas características).]