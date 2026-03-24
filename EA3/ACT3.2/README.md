# 🚀 Análisis de Impacto de Estrategias de Remediación

Esta guía detalla los pasos de instalación de herramientas, autenticación en AWS y el despliegue de un clúster de Kubernetes (EKS) utilizando únicamente la AWS CLI.

# 📌 **Índice**

1.  🛠️ Pre-requisitos
2.  ⚙️ Configuración de Entorno y Herramientas
    * 2.1. Instalación de Docker y Componentes (Debian/Ubuntu)
    * 2.2. Instalación de Kubectl (v1.30)
    * 2.3. Instalación de Eksctl (Opcional)
3.  ☁️ Autenticación y Configuración de AWS
    * 3.1. Configuración de Credenciales AWS
    * 3.2. Creación y Login en ECR (Elastic Container Registry)
    * 3.3. Construcción, Etiquetado y Push de la Imagen
4.  🚀 Creación de EKS con AWS CLI
    * 4.1. Crear el Control Plane de EKS
    * 4.2. Crear el Grupo de Nodos (Worker Nodes)
5.  💻 Conexión y Despliegue en Kubernetes
    * 5.1. Configurar Conexión Kubeconfig y Verificar Nodos
    * 5.2. Despliegue de la Aplicación | Rollback - Rolling Update
    * 5.3. Despliegue de la Aplicación | Rollback - All-In-Once
    * 5.4. Despliegue de la Aplicación | Rollback - Canary
    * 5.5. Despliegue de la Aplicación | Rollback - Blue/Green

---

# 🛠️ **Pre-requisitos**

Antes de comenzar la guía, asegúrate de contar con lo siguiente:

* **Sistema Operativo:** Un servidor o entorno de trabajo basado en **Debian/Ubuntu**.
* **Permisos de Usuario:** Acceso a comandos `sudo` para la instalación de paquetes.
* **Credenciales de AWS:** Un conjunto de credenciales (`ACCESS_KEY`, `SECRET_KEY`, `SESSION_TOKEN`) o credenciales de IAM con permisos suficientes para administrar recursos de **ECR** y **EKS**.
* **Conectividad de Red:** IDs de las **Subredes Públicas** y **Privadas** de tu VPC para la configuración del clúster EKS.
* **Archivos de Manifiesto:** Los archivos **YAML** necesarios para los despliegues (`rolling-update.yaml`, `all-in-once.yaml`, etc.) con los *placeholders* de la URI de ECR.


## 1️⃣ Configuración de Entorno y Herramientas

Instalaremos las dependencias necesarias y las herramientas de línea de comandos para interactuar con Docker, Kubernetes y AWS.

### 1.1. Instalación de Docker y Componentes (Debian/Ubuntu)

Estos comandos configuran e instalan el motor Docker en su servidor Debian.

#### 1. Actualizar sistema e instalar dependencias iniciales
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release
```

#### 2. Agregar clave GPG y repositorio oficial de Docker
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### 3. Instalar Docker Engine, CLI y Buildx
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### 4. Verificar instalación
```bash
sudo docker version
sudo docker info
```

### 1.2. Instalación de Kubectl (Versión 1.30)
kubectl es la herramienta estándar para interactuar con el Control Plane de Kubernetes. Debe coincidir con la versión de su clúster (v1.30).

#### 1. Instalar dependencias
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

#### 2. Agregar la clave GPG y el repositorio de Kubernetes
```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

#### Definir el repositorio para la versión 1.30
```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] [https://pkgs.k8s.io/core:/stable:/v1.30/deb/](https://pkgs.k8s.io/core:/stable:/v1.30/deb/) /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

#### 3. Instalar kubectl
```bash
sudo apt-get update
sudo apt-get install -y kubectl bc
```

### 1.3. Instalación de Eksctl (Opcional pero Recomendado)

#### Descarga el binario oficial más reciente de eksctl
```bash
curl --silent --location "[https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname](https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname) -s)_amd64.tar.gz" | tar xz -C /tmp
```

#### Mueve el binario a una ubicación en el PATH
```bash
sudo mv /tmp/eksctl /usr/local/bin
```

#### Verifica la instalación
```bash
eksctl version
```

## 2️⃣ Autenticación y Configuración de AWS

Configuremos las credenciales necesarias y el repositorio de imágenes.

### 2.1. Configuración de Credenciales AWS
⚠️ Acción Requerida: Reemplace los valores TU_ACCESS_KEY_ID, TU_SECRET_ACCESS_KEY y TU_SESSION_TOKEN con sus credenciales de laboratorio.

#### 1. Exportar variables de entorno de AWS
```bash
export AWS_ACCESS_KEY_ID="TU_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="TU_SECRET_ACCESS_KEY"
export AWS_SESSION_TOKEN="TU_SESSION_TOKEN"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2.2. Creación y Login en ECR (Elastic Container Registry)
Crearemos el repositorio y autenticaremos Docker para poder subir la imagen.

#### 1. Crear el repositorio ECR (si no existe)
```bash
aws ecr create-repository --repository-name duoc-lab
```

#### 2. Autenticar Docker con ECR (Reemplaza 885869691689 con tu Account ID si es necesario)
#### Este comando obtiene un token de login temporal y lo pasa a Docker. Recuerda reemplazar en el comando por tu cuenta de AWS.
```bash
aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin [TU-CUENTA-AWS].dkr.ecr.us-east-1.amazonaws.com
```

### 2.3. Construcción, Etiquetado y Push de la Imagen
Definiremos variables de tag para mantener la imagen organizada y la subiremos al repositorio.

#### Definir variables. Usamos 'latest' para el despliegue inicial.
```bash
export ACCOUNT_ID="" # Reemplaza con tu Account ID
export REGION="us-east-1"
export REPO_NAME="duoc-lab"
export IMAGE_TAG_V1="v1.0"
export ECR_URI_V1="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG_V1"
export IMAGE_TAG_V2="v2.0"
export ECR_URI_V2="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG_V2"

echo "URI V1 (Stable/Blue): $ECR_URI_V1"
echo "URI V2 (Canary/Green): $ECR_URI_V2"
```

#### 1. Construir la imagen de Docker usando el Dockerfile en el directorio actual (Para Canary | Blue Green)

```bash
git clone https://github.com/Fundacion-Instituto-Profesional-Duoc-UC/AUY1104-CICLO-DE-VIDA-DEL-SOFTWARE-II
cd AUY1104-CICLO-DE-VIDA-DEL-SOFTWARE-II
sudo docker build -t $IMAGE_TAG_V1 --build-arg BUILD_COLOR="Blue" .
echo "Imagen local V1.0 construida con el tag: $IMAGE_TAG_V1"
# Previo a realizar el build de V2, descomenta las siguientes lineas en tu archivo index.js
const startTime = Date.now();
const errorDelaySeconds = 120; // 2 minutos
# Esto hará, que despues de 2 minutos tu aplicación falle de manera obligatoria.
sudo docker build -t $IMAGE_TAG_V2 --build-arg BUILD_COLOR="Green" .
echo "Imagen local V2.0 construida con el tag: $IMAGE_TAG_V2"
sudo docker images
```

#### 2. Etiquetar la imagen local con la URI completa de ECR
```bash
sudo docker tag $IMAGE_TAG_V1 $ECR_URI_V1
echo "Imagen V1.0 etiquetada como: $ECR_URI_V1"
sudo docker tag $IMAGE_TAG_V2 $ECR_URI_V2
echo "Imagen V2.0 etiquetada como: $ECR_URI_V2"
sudo docker images
```

#### 3. Subir (Push) la imagen a ECR
```bash
sudo docker push $ECR_URI_V1
echo "¡Push a ECR completado! V1.0 ya está disponible en $ECR_URI_V1."
sudo docker push $ECR_URI_V2
echo "¡Push a ECR completado! V2.0 ya está disponible en $ECR_URI_V2."
```

## 3️⃣ Creación de EKS con AWS CLI
Utilizaremos la CLI para crear el clúster (Control Plane) y el grupo de nodos (Worker Nodes).

⚠️ Acción Requerida: Reemplace los siguientes placeholders con los valores de su laboratorio:

```TU-ARN-AWS-LABROLE```: ARN del rol de IAM que usará EKS.

```ID-SUBNET-PRIVADA-1, ID-SUBNET-PRIVADA-2```: IDs de subredes privadas.

```ID-SUBNET-PUBLICA-1, ID-SUBNET-PUBLICA-2```: IDs de subredes públicas.

### 3.1. Crear el Control Plane de EKS

# Crea el clúster EKS (Control Plane) y espera a que esté activo (Aproximadamente 10 a 20 Minutos)
```bash
aws eks create-cluster \
    --name duoc-eks-cluster-cli \
    --role-arn "TU-ARN-AWS-LABROLE" \
    --resources-vpc-config subnetIds=ID-SUBNET-PRIVADA-1,ID-SUBNET-PRIVADA-2,endpointPublicAccess=true,endpointPrivateAccess=false \
    --kubernetes-version 1.30 \
    --region us-east-1
```
# Monitorear estado (esperar 10-15 minutos)
```bash
aws eks describe-cluster --name duoc-eks-cluster-cli --region us-east-1 --query 'cluster.status'
```

### 3.2. Crear el Grupo de Nodos (Worker Nodes)

# Crea el grupo de nodos (EC2 Instances) que alojará sus Pods
```bash
aws eks create-nodegroup \
    --cluster-name duoc-eks-cluster-cli \
    --nodegroup-name standard-workers-cli \
    --scaling-config minSize=1,maxSize=1,desiredSize=1 \
    --disk-size 20 \
    --subnets ID-SUBNET-PUBLICA-1 ID-SUBNET-PUBLICA-2 \
    --instance-types t3.small \
    --node-role "TU-ARN-AWS-LABROLE" \
    --ami-type AL2023_x86_64_STANDARD \
    --region us-east-1
```

## 4️⃣ Conexión y Despliegue en Kubernetes

Una vez que el clúster esté activo y los nodos se hayan unido, podemos desplegar la aplicación.

### 4.1. Configurar Conexión Kubeconfig y Verificar Nodos

#### 1. Agrega el contexto del clúster a tu archivo kubeconfig local
```bash
aws eks update-kubeconfig --name duoc-eks-cluster-cli --region us-east-1
```

#### 2. Verifica que los nodos estén en estado Ready (esto puede tardar unos minutos)
```bash
kubectl get nodes -o wide -w
```

### 4.2. Despliegue de la Aplicación - Rolling Update
Revisa que tengas un archivo YAML (deployment.yaml o similar) que define tu Deployment y Service (LoadBalancer). Adicionalmente, en cada manifiesto, deberás reemplazar el valor de ```$ECR_URI_V1 | $ECR_URI_V1```, por los valores de tus imagenes en ECR.

1. Aplicar el manifiesto de Deployment y Service y realizaremos el rollback de manera manual.
```bash
# Modifica el campo ECR_URI_V1 por tu imagen V1
vi EA2/ACT2.2/ROLLING-UPDATE/rolling-update.yaml 
kubectl apply -f EA2/ACT2.2/ROLLING-UPDATE/rolling-update.yaml
```

2. Verificar los recursos desplegados
```bash
kubectl get pods
kubectl get svc
```

3. Modifica el campo ECR_URI_V2 para el deploymeny
```bash
vi EA2/ACT2.2/ROLLING-UPDATE/rolling-update.yaml 
kubectl apply -f EA2/ACT2.2/ROLLING-UPDATE/rolling-update.yaml
```

4. Verificar los recursos desplegados
```bash
kubectl get pods
kubectl get svc
# Espera 2 minutos, hasta que se genere una falla, puedes ejecutar kubectl get pods -w para mantener la sesion activa y verificar la falla en vivo.
```

Intenta volver a la version V1, y reflexiona como es la secuencia de rollback en este caso, y valida si es el resultado que esperas.

### 4.3 Despliegue de la Aplicación - All-In-Once

1. Aplicar el manifiesto de Deployment y Service
```bash
# Modifica el campo ECR_URI_V1 por tu imagen V1
vi EA2/ACT2.2/ALL-IN-ONCE/all-in-once.yaml
kubectl apply -f EA2/ACT2.2/ALL-IN-ONCE/all-in-once.yaml
```

2. Verificar los recursos desplegados
```bash
kubectl get pods
kubectl get svc
```


3. Modifica el campo ECR_URI_V2 para el deploymeny
```bash
# Modifica el campo ECR_URI_V2 por tu imagen V2
vi EA2/ACT2.2/ALL-IN-ONCE/all-in-once.yaml
kubectl apply -f EA2/ACT2.2/ALL-IN-ONCE/all-in-once.yaml
```

4. Verificar los recursos desplegados
```bash
kubectl get pods
kubectl get svc
# Espera 2 minutos, hasta que se genere una falla, puedes ejecutar kubectl get pods -w para mantener la sesion activa y verificar la falla en vivo.
```

Intenta volver a la version V1, y reflexiona como es la secuencia de rollback en este caso, y valida si es el resultado que esperas.

### 4.4 Despliegue de la Aplicación - Canary

1. Aplicar el manifiesto de Deployment y Service
```bash
# Modifica el campo ECR_URI_V1 | ECR_URI_V2 por tu imagen V1 | V2 respectivamente.
vi EA2/ACT2.2/CANARY/canary.yaml
kubectl apply -f EA2/ACT2.2/CANARY/canary.yaml
```

2. Verificar los recursos desplegados
```bash
# Verifica el estado de los Pods (deberías ver 3, dos de V1 y uno de V2)
kubectl get pods -l app=duoc-app 
# Verifica los Deployments
kubectl get deployments
# Verifica el Service y obtén el Public DNS del LoadBalancer
kubectl get svc duoc-app-canary-service
```

3. Promoción

Para promover V2.0 al 100% del tráfico, editas el Deployment de la versión estable (duoc-app-stable-v1) y reduces sus réplicas a 0. Luego, editas el Deployment Canary (duoc-app-canary-v2) y aumentas sus réplicas al total deseado (ej: 3).

```bash
# Reduce las réplicas V1 a 0 (eliminando el entorno antiguo)
kubectl scale deployment duoc-app-stable-v1 --replicas=0

# Escala las réplicas V2 a 3 (entorno nuevo al 100%)
kubectl scale deployment duoc-app-canary-v2 --replicas=3
```
Intenta volver a la version V1, y reflexiona como es la secuencia de rollback en este caso, y valida si es el resultado que esperas.

5. Rollback.

# Edita el Deployment V2 in-place para usar la imagen V1

```bash
# Escala V1 de 0 a 3 réplicas
kubectl scale deployment duoc-app-stable-v1 --replicas=3
# Escala V2 de 3 a 0 réplicas
kubectl scale deployment duoc-app-canary-v2 --replicas=0
```

### 4.5 Despliegue de la Aplicación - Blue/Green

1. Aplicar el manifiesto de Deployment y Service
```bash
# Modifica el campo ECR_URI_V1 | ECR_URI_V2 por tu imagen V1 | V2 respectivamente.
vi EA2/ACT2.2/BLUE-GREEN/blue-green.yaml
kubectl apply -f EA2/ACT2.2/BLUE-GREEN/blue-green.yaml
```
2. Verificar el Estado Inicial
Asegúrate de que ambos Pods están Running y obtén la URL pública.

```bash
# Deberías ver 1 Pod 'duoc-app-blue' y 1 Pod 'duoc-app-green'
kubectl get pods

# Obtén la URL del LoadBalancer (EXTERNAL-IP/CNAME)
kubectl get svc duoc-app-bg-service
```

3. Realizar el Switch a Green (Ida)
Ahora realizaremos el cambio de selector del Service.

```bash
# Cambia el selector del Service de 'blue' a 'green'
kubectl patch service duoc-app-bg-service -p '{"spec": {"selector": {"version": "green"}}}'
```
Verifica que el tráfico público llega solo a la versión Blue. Para un servicio de tipo LoadBalancer, el acceso inicial se realiza a través de la Public DNS, que se obtiene posterior a la ejecución del comando ```kubetl get svc``` como ```ID.us-east-1.elb.amazonaws.com``` . Una vez que obtengas el EXTERNAL-IP (el CNAME del LoadBalancer) del servicio duoc-app-bg-service. **Resultado Esperado:** Hola! Soy Green (Confirmación: Green está en vivo).

Intenta volver a la version V1, y reflexiona como es la secuencia de rollback en este caso, y valida si es el resultado que esperas.

4. Rollback

# Cambia el selector del Service de 'green' de vuelta a 'blue'
```bash
kubectl patch service duoc-app-bg-service -p '{"spec": {"selector": {"version": "blue"}}}'
```

## 5️⃣ Ejercicio Adicional: Integración con GitHub Actions

El siguiente ejercicio integra estrategias de despliegue con la automatización CI/CD, permitiendo pruebas de Hotfix y Feature Toggles sin modificar el código fuente principal.

1. Prerrequisitos de GitHub Actions
- Repositorio de código en GitHub.
- Secrets de GitHub configurados con credenciales de AWS (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION).

2. Hotfix Rápido (Usando el Flujo Canary/Rolling Update)
Escenario: Se detecta un bug crítico en la versión V2.0 que está al 100% del tráfico. Se necesita desplegar un hotfix (V2.1) directamente.

| Paso | Acción en GitHub Actions (Workflow) | Comando K8s (Resumen) |
| :--- | :--- | :--- |
| **1. Push del Hotfix** | Se realiza un *push* a la rama `main` con un `Dockerfile` que usa un *build argument* para cambiar el número de versión (`V2.1`) o color. | `docker build -t V2.1...` |
| **2. Despliegue Rápido** | El *Workflow* CI/CD construye `V2.1`, lo sube a ECR y luego ejecuta un **Rolling Update** en el Deployment activo (`duoc-app-canary-v2`) cambiando la imagen a `V2.1`. | `kubectl set image deployment/duoc-app-canary-v2 duoc-app-container=$ECR_URI_V2_1` |
| **3. Verificación** | El *Workflow* espera 5 minutos y usa `kubectl rollout status` para confirmar que el despliegue finalice sin errores. | `kubectl get pods -l version=canary` |

3. Feature Toggle (Usando el Flujo Blue/Green)
Escenario: La nueva característica X (V2) fue desplegada a Green, pero no está lista para producción. Queremos que el código V2 esté en el clúster, pero sea invisible.

| Paso | Acción en GitHub Actions (Workflow) | Comando K8s (Resumen) |
| :--- | :--- | :--- |
| **1. Despliegue al Ambiente Inactivo (Green)** | El *Workflow* despliega la versión `V2.0` al Deployment `duoc-app-green`. El Service aún apunta a `blue`. | `kubectl apply -f deployment-green-v2.yaml` |
| **2. Feature Toggle (Toggle OFF)** | El código V2 incluye una variable de entorno **`FEATURE_X_ENABLED=false`**. La característica está desactivada por defecto. | `deployment-green-v2.yaml` contiene la variable de entorno. |
| **3. Toggle ON (Promoción Blue/Green)** | Un humano (o una herramienta A/B Testing) aprueba la promoción. El *Workflow* ejecuta el *switch* del Service. | `kubectl patch service duoc-app-bg-service -p '{"spec": {"selector": {"version": "green"}}}'` |
| **4. Feature Toggle OFF (Rollback)** | Si V2.0 falla, se revierte instantáneamente. El código V2 aún existe en el *cluster*, pero no está en el tráfico. | `kubectl patch service duoc-app-bg-service -p '{"spec": {"selector": {"version": "blue"}}}'` |