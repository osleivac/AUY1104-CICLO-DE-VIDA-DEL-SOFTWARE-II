# Parametrización de Plantillas para Reutilización CI/CD (Node.js, Docker, AWS ECR)

Este documento proporciona la guía completa para instalar dependencias locales, ejecutar pruebas, construir contenedores Docker, subirlos a AWS Elastic Container Registry (ECR) y finalmente automatizar todo el proceso mediante un pipeline de GitHub Actions (CI/CD).

El objetivo es que estudiantes comprendan tanto el flujo manual como el automatizado, logrando un pipeline moderno, seguro y profesional.

Trabajaremos en construir un pipeline, con distintas opciones disponibles, para poder realizar el flujo lógico de publicación de una imagen docker a un ECR en AWS.

------------------------------------------------------------------------

# 📌 **Índice**

1.  Pre-requisitos
2.  Ejecución del Proyecto Node.js
3.  Construcción y Subida de Imágenes Docker a AWS ECR
4.  Automatización con GitHub Actions (CI/CD)
5.  Documentación Oficial de Acciones Usadas

------------------------------------------------------------------------

# 🧩 **Pre-requisitos**
Antes de comenzar, asegúrate de contar con:

- Credenciales de AWS para laboratorio o cuenta propia.
- GitHub repository donde configuraremos el pipeline.

Trabajaremos en construir un pipeline, con distintas opciones disponibles, para poder realizar el flujo logico de publicacion de una imagen docker a un ECR en AWS.

------------------------------------------------------------------------

# Construcción

## 1. 🎯 Adaptación de Triggers (on)
La plantilla actual está diseñada para master (producción). Para un entorno de Staging o Desarrollo, debemos cambiar la rama:

| Tarea de Ajuste | Plantilla Original | Plantilla Adaptada (Staging/Develop) |
| :--- | :--- | :--- |
| **Rama de PUSH** | `master` | Cambiar a: `staging` o `develop` |
| **Evento de RELEASE** | Mantener/Eliminar | Si es Staging, **eliminar** el trigger de `release`. |

Ejemplo de ajuste para develop:
```bash
on:
  push:
    branches:
      - develop # La integración continua ahora se ejecuta en develop
```

## 2. 🛡️ Adaptación de Condicionales (if)
Utiliza el if para controlar pasos sensibles, como la subida a ECR.

Escenario: Queremos que el job de Contenerización y Registro solo se ejecute cuando se hace un push directo a la rama (no durante una revisión de pull_request).

```bash
jobs:
  build_and_push_ecr:
    # El job solo corre si el evento NO es un pull_request
    if: ${{ github.event_name != 'pull_request' }} 
    # ... resto del job
```

## 3. 🔑 Ajuste de Variables y Secretos
Para el nuevo proyecto o entorno, es obligatorio actualizar las variables sensibles y de configuración:

| Variable/Secreto | Propósito de la Modificación |
| :--- | :--- |
| `vars.ECR_REPOSITORY` | Debe apuntar al **nuevo repositorio** de ECR (ej. `mi-app-frontend`). |
| `vars.AWS_REGION` | Si el nuevo proyecto está en otra región, debe ser actualizado. |
| `secrets.AWS_ACCESS_KEY_ID` | Si el nuevo entorno tiene credenciales de AWS separadas, deben ser inyectadas. |

Aquí tienes la sección de documentación y la explicación técnica del ciclo de vida de la caché, formateada profesionalmente en Markdown.

He integrado los fragmentos de código YAML proporcionados para ilustrar exactamente dónde y cómo se implementa la estrategia de caché tanto para dependencias de Node.js como para capas de Docker.

## 4. 📝 Tarea de Documentación y Validación Práctica
Como parte del entregable final, el estudiante debe documentar los parámetros definidos y realizar una validación práctica del pipeline ajustado.

### 4.1. Validación Práctica

Ejecuta el pipeline original y luego el ajustado (con caché).

Compara los tiempos de ejecución (Duration) en la pestaña "Actions" de GitHub.

Pregunta a responder: ¿Se redujo el tiempo total al cambiar los triggers o al reutilizar la caché en la segunda ejecución?

### 4.2. Documentación Requerida

Explica el propósito y alcance de la nueva rama configurada (ej. develop vs master).

Justifica por qué modificaste los triggers (on:) y los condicionales (if:) para este segundo entorno.

Aquí tienes todo el contenido consolidado y formateado estrictamente como código Markdown. Puedes copiar el bloque siguiente y guardarlo directamente en un archivo con extensión .md (por ejemplo, guia_ci_cd.md).

## 4. 📝 Tarea de Documentación y Validación Práctica

Como parte del entregable final, el estudiante debe documentar los parámetros definidos y realizar una validación práctica del pipeline ajustado.

### 🔍 Validación y Documentación

> **1. Validación Práctica**
> * Ejecuta el pipeline original y luego el ajustado (con caché).
> * Compara los **tiempos de ejecución** (*Duration*) en la pestaña "Actions" de GitHub.
> * **Pregunta a responder:** ¿Se redujo el tiempo total al cambiar los triggers o al reutilizar la caché en la segunda ejecución?

> **2. Documentación Requerida**
> * Explica el propósito y alcance de la nueva rama configurada (ej. `develop` vs `master`).
> * Justifica **por qué** modificaste los *triggers* (`on:`) y los condicionales (`if:`) para este segundo entorno.

---

## 💾 5. Optimización Avanzada: El Ciclo de Vida de la Caché

El sistema de caché en CI/CD es una estrategia crítica que reduce drásticamente el tiempo de ejecución. En este pipeline, utilizamos dos niveles de caché: **Caché de Dependencias (NPM)** y **Caché de Capas Docker (Registry)**.

### 5.1. Concepto General: Miss vs. Hit

La razón por la que la caché falla la primera vez y "vuela" en las siguientes se debe a la naturaleza del proceso: **primero se debe guardar para poder restaurar**.

#### 🔴 Primera Ejecución: "Cache Miss" (Fallo)
1.  **Búsqueda:** GitHub busca una "huella digital" (*hash*) basada en tu `package-lock.json`.
2.  **Resultado:** Al ser nuevo (o haber cambiado las dependencias), no encuentra coincidencias (**Miss**).
3.  **Acción:** El runner descarga todo de internet (`npm registry`) y construye todas las capas de Docker desde cero.
4.  **Guardado:** Al finalizar con éxito, GitHub comprime las dependencias y Docker guarda las capas base para el futuro.

#### 🟢 Segunda Ejecución: "Cache Hit" (Acierto)
1.  **Búsqueda:** El sistema recalcula el *hash* y **encuentra** el paquete guardado (**Hit**).
2.  **Acción:** Restaura los archivos instantáneamente.
3.  **Resultado:** `npm ci` tarda segundos en lugar de minutos, y Docker reutiliza capas existentes sin reconstruirlas.

---

### 5.2. Implementación A: Caché de Dependencias (Node.js)

Para el flujo de pruebas (`Build and Test`), utilizamos la acción oficial `setup-node`. Esta acción abstrae la complejidad de guardar y restaurar carpetas.

**Configuración en el YAML:**
Observa el parámetro `cache: 'npm'`. Esto le indica a GitHub Actions que genere el hash basado en `package-lock.json` y guarde el directorio `~/.npm` automáticamente.

### 5.3. Implementación B: Caché de Capas Docker (Registry Cache)

Para la construcción de la imagen, usamos una estrategia más avanzada: **Registry Caching**. En lugar de guardar la caché en GitHub, le pedimos a Docker que busque capas ya construidas en **AWS ECR**.

**¿Cómo funciona?**

1.  **`cache-from`**: Antes de construir, Docker verifica si la imagen `latest` en ECR ya tiene capas que coinciden con el código actual (ej. el S.O. base o las librerías).
2.  **`cache-to`**: Al terminar, guarda metadatos en la imagen (`inline`) para que la próxima ejecución pueda reusarlas.

### 🔑 ¿Cuándo se Rompe la Caché?

El ciclo se reinicia (volviendo a un "Cache Miss") si:

* **Cambias `package-lock.json`:** Al añadir una librería, la "huella digital" (hash) cambia.
* **Cambias el `Dockerfile`:** Si cambias la imagen base (ej. de `FROM node:20` a `node:21`), las capas de Docker deben reconstruirse.
* **Expiración:** GitHub elimina las cachés tras **7 días de inactividad**.