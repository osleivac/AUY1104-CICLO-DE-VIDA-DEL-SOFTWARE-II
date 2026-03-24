# Identificación de Escenarios de Error

Esta actividad se centra en modificar intencionalmente los archivos YAML de GitHub Actions para forzar fallos en diferentes etapas de los flujos de Build & Test (NPM), ECR Build & Push (Docker) y Despliegue EKS (Kubernetes).

## 1. 🛠️ Pipeline: Build and Test
Este flujo se encarga de la integración continua (CI), instalando dependencias y ejecutando pruebas/auditoría. Para cada indicación que señale "Modificación a simular" se debe realizar la respectiva modificación en el pipeline en su repositorio Github, en la rama desde donde se tiene la version estable, hacer el commit y el push, y entender y analizar el impacto en la ejecución.

| Escenario de Error | Modificación a Simular | Resultado Esperado | Contingencia (Cómo manejarlo) |
| :--- | :--- | :--- | :--- |
| **Error 1: Fallo de Instalación** | Modificar el comando `npm ci` a `npm install-fail` (un comando inexistente) o a un comando que falle intencionalmente. | El job fallará en el paso Instalar Dependencias porque el comando no es reconocido o es incorrecto. | Asegurar que el comando sea `npm ci` o `npm install` y que el `package.json` esté correcto. Verificar la versión de Node.js. |
| **Error 2: Fallo de Pruebas** | Modificar el comando `npm test` a `exit 1` (un comando que siempre retorna un código de error). | El job fallará en el paso Ejecutar Pruebas Automatizadas al recibir un código de salida distinto de cero, deteniendo la pipeline. | Revisar y corregir los tests unitarios o de integración fallidos antes de la PR/Merge. |
| **Error 3: Versión de Node.js Incorrecta** | Cambiar la `node-version: 20` a `node-version: 99` (una versión inexistente o no soportada). | El paso Configurar Node.js v20 con Caché fallará, ya que `actions/setup-node@v4` no podrá encontrar la versión solicitada. | Corregir la versión de Node.js al valor correcto y soportado por la aplicación (20 en este caso). |

## 2. 🐳 Pipeline: ECR Build & Push
Este flujo se encarga de construir la imagen Docker y subirla a AWS ECR.

| Escenario de Error | Modificación a Simular | Resultado Esperado | Contingencia (Cómo manejarlo) |
| :--- | :--- | :--- | :--- |
| **Error 1: Credenciales de AWS Inválidas** | En el paso **Configurar Credenciales AWS**, modificar intencionalmente el nombre de una `secret`, ej: `aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_FAIL }}`. | El paso fallará al intentar configurar las credenciales, ya que una o más variables `secrets` serán nulas o incorrectas, impidiendo el `Login en ECR`. | Verificar que los `secrets` estén configurados correctamente en el repositorio y que los nombres coincidan exactamente con el archivo YAML. |
| **Error 2: Repositorio ECR Incorrecto** | En el `env` del job, cambiar `ECR_REPOSITORY: ${{ vars.ECR_REPOSITORY }}` a `ECR_REPOSITORY: repo-inexistente`. | El paso **Login en Amazon ECR** podría pasar, pero el paso **Build, tag, and push image...** fallará con un error de acceso denegado o repositorio no encontrado durante el `push`. | Asegurar que el repositorio ECR especificado en las `vars` exista y que las credenciales de AWS tengan permisos de `push` sobre él. |
| **Error 3: Dockerfile Inválido** | **No se simula en el YAML**, pero la simulación sería agregar un comando incorrecto o un error de sintaxis en el archivo `Dockerfile`. | El paso **Build, tag, and push image...** fallará durante la fase de `build` con un mensaje de error del `docker build` (ej: `Step 3/X failed`). | Corregir la sintaxis o lógica del `Dockerfile` (ej: ruta incorrecta, comando mal escrito). |

## 3. ☸️ Pipeline: Despliegue EKS - Estrategias de Rollout
Este flujo se encarga del despliegue en Kubernetes (EKS) utilizando diversas estrategias.

| Escenario de Error | Modificación a Simular | Resultado Esperado | Contingencia (Cómo manejarlo) |
| :--- | :--- | :--- | :--- |
| **Error 1: Acceso a EKS Denegado/Cluster Inexistente** | En el `workflow_dispatch` del *input*, cambiar `eks_cluster_name: 'duoc-eks-cluster-cli'` a `'cluster-inexistente'`. | El paso **Configurar Kubectl para EKS** fallará porque no podrá establecer el contexto con un cluster inexistente. | Verificar el nombre del cluster EKS y los permisos de las credenciales de AWS para acceder a él (`aws-actions/eks-set-context@v4` necesita permisos). |
| **Error 2: YAML de Kubernetes Inválido** | **No se simula en el YAML**, pero la simulación sería modificar el archivo `k8s/rolling-update-v2.yaml` para que tenga un error de sintaxis o de esquema. | El paso **Ejecutar Rolling Update** (o la estrategia elegida) fallará en el comando `kubectl apply -f ...` con un error de parsing o validación de YAML. | Corregir la sintaxis o la estructura del archivo de despliegue YAML de Kubernetes. |
| **Error 3: Fallo en el Rollout (Timeout)** | **No se simula modificando el YAML**, pero se simula en el entorno: hacer que la nueva versión de la imagen Docker tenga un error de inicio (CrashLoopBackOff). | El comando `kubectl rollout status deployment/... --timeout=300s` agotará el tiempo de espera (timeout) ya que la nueva versión no podrá alcanzar el estado "Rollout Complete". | Implementar un `rollout undo` o *rollback* a la versión anterior estable y diagnosticar la razón del fallo (logs, eventos) de los nuevos pods. |