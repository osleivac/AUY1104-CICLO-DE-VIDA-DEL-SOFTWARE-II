# Actividad 3.4: Implementación y Documentación de la Estrategia Integral de Remediación

Esta actividad final requiere que los estudiantes sinteticen todo el conocimiento adquirido sobre las estrategias de despliegue, el análisis de fallos, y los tiempos de recuperación (rollback), para proponer y documentar la estrategia de remediación óptima para una aplicación crítica, justificando su elección con la evidencia obtenida en las simulaciones manuales.

## Objetivo de la Actividad
Elaborar un informe ejecutivo (Documentación de Estrategia Integral) que justifique la selección de la mejor estrategia de despliegue para una aplicación con altos requisitos de continuidad operativa (Cero Downtime) y reducción de riesgos.

## Tareas a Realizar

### 1. Selección y Justificación de la Estrategia (La Decisión)
Basándose en los resultados prácticos del Análisis de Impacto de Estrategias de Remediación (Actividad anterior), el estudiante debe:

Seleccionar una Estrategia Única: Elija la estrategia de despliegue (Rolling Update, All-in-Once, Canary o Blue/Green) que mejor se alinee con los requisitos de Cero Downtime y Rollback Atómico (instantáneo) para una aplicación de misión crítica.

Fundamentar la Elección: Justifique por qué la estrategia elegida es superior a las demás en términos de continuidad del negocio ante un fallo. Utilice el concepto de Rollback Atómico versus Rollback No Atómico para defender su posición.

### 2. Definición de Métricas Clave (El Impacto)
Para la estrategia elegida, defina cómo se medirán el éxito y la resiliencia en un entorno de producción:

Tiempo Medio de Reversión (MTTR - Mean Time To Recovery): Defina el MTTR esperado para la estrategia elegida (ej., 5 segundos en Blue/Green). Justifique por qué este tiempo es esencial para la continuidad del negocio.

Métrica de Exposición al Fallo: Defina la métrica que cuantifica la exposición del usuario al fallo.

Ejemplo para Canary: Porcentaje máximo de tráfico expuesto (ej., 10%).

Ejemplo para Blue/Green: 0% (la versión Green falla, pero el tráfico sigue en Blue).

### 3. Documentación de la Secuencia de Remediación (El Procedimiento)
Documente el procedimiento paso a paso que el operador o el pipeline automatizado (GitHub Actions) ejecutarían para realizar la remediación, asumiendo que la nueva versión (V2) falló.

Utilice el siguiente formato de tabla en su informe:

| Estrategia Elegida | Detección del Fallo (Trigger) | Comando de Rollback (Acción) |
| :--- | :--- | :--- |
| **[SU ELECCIÓN]** | *Ej: `kubectl rollout status` agotó el tiempo de espera.* | *Ej: `kubectl patch service duoc-app-bg-service -p '{"spec": {"selector": {"version": "blue"}}}'`*

Análisis del Comando: Explique en un párrafo por qué ese comando específico de rollback es el más rápido y cómo impacta directamente en el MTTR.

### 4. Conclusiones Ejecutivas
El informe debe cerrar con un resumen de los hallazgos:

Resiliencia Operativa: Resuma cómo la estrategia elegida transforma el riesgo de un fallo catastrófico (ej., All-in-Once) en un evento controlado y mitigado.

Integración con CI/CD: Explique brevemente cómo la automatización en GitHub Actions haría este proceso de remediación aún más robusto (ej., un workflow de emergencia de rollback que se ejecuta automáticamente al detectar el rollout status fallido).

## Formato del Informe
El informe final debe entregarse con la siguiente estructura:

- Título: Implementación y Documentación de la Estrategia Integral de Remediación

- Introducción: Resumen del objetivo de la actividad.

- Análisis Comparativo (Evidencia): Breve comparación de MTTR de las 4 estrategias.

- Estrategia Seleccionada: Justificación detallada (Continuidad del Negocio y Riesgo).

- Procedimiento de Remediación: La tabla paso a paso y el análisis del comando de rollback.

- Conclusiones.