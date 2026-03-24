# Creación de Plantillas Reutilizables en CI/CD (Node.js, Docker, AWS ECR)

Este documento proporciona la guía completa para instalar dependencias
locales, ejecutar pruebas, construir contenedores Docker, subirlos a AWS
Elastic Container Registry (ECR) y finalmente automatizar todo el
proceso mediante un pipeline de **GitHub Actions (CI/CD)**.

El objetivo es que estudiantes comprendan tanto el flujo manual como el
automatizado, logrando un pipeline moderno, seguro y profesional.

------------------------------------------------------------------------

# 📌 **Índice**

1.  Pre-requisitos\
2.  Instalación Local de Dependencias y Herramientas\
3.  Ejecución del Proyecto Node.js\
4.  Construcción y Subida de Imágenes Docker a AWS ECR\
5.  Automatización con GitHub Actions (CI/CD)\
6.  Documentación Oficial de Acciones Usadas

------------------------------------------------------------------------

# 🧩 Pre-requisitos

Antes de comenzar, asegúrate de contar con:

-   Un sistema basado en Debian/Ubuntu.
-   Docker instalado en tu máquina.
-   Credenciales de AWS para laboratorio o cuenta propia.
-   GitHub repository donde configuraremos el pipeline.
-   Node Version Manager (nvm) para gestionar versiones de Node.js.

------------------------------------------------------------------------

# ⚙️ Instalación Local de Dependencias y Herramientas

Este apartado cubre la configuración básica necesaria para desarrollar,
ejecutar y preparar el microservicio antes de automatizarlo.

------------------------------------------------------------------------

## 1️⃣ Instalación de Node Version Manager (nvm)

Node Version Manager permite instalar y administrar múltiples versiones
de Node.js en el mismo equipo.

### 1.1. Instalar herramientas base

``` bash
sudo apt update
sudo apt install git curl -y
```

### 1.2. Descargar e instalar nvm

``` bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```

### 1.3. Cargar nvm en la sesión actual

``` bash
source ~/.bashrc
```

------------------------------------------------------------------------

## 2️⃣ Instalar y Configurar Node.js

### Instalar Node.js v20

``` bash
nvm install 20
```

### Usar Node.js v20

``` bash
nvm use 20
```

### Verificar versión

``` bash
node -v
```

------------------------------------------------------------------------

# 🚀 Ejecución del Proyecto Node.js

### 1. Descargar el repositorio

``` bash
git clone [REPO]
cd AUY1104-CICLO-DE-VIDA-DEL-SOFTWARE-II
```

### 2. Instalar dependencias

``` bash
npm install
```

### 3. Ejecutar pruebas

``` bash
npm test
```

------------------------------------------------------------------------

# 🐳 Construcción y Subida de Imágenes Docker a AWS ECR

Aquí verás el flujo completo para construir una imagen, etiquetarla y
subirla al repositorio de AWS.

------------------------------------------------------------------------

## 1️⃣ Instalación de Docker (Debian/Ubuntu)

### 1.1. Actualizar sistema e instalar dependencias

``` bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release
```

### 1.2. Agregar repositorio oficial de Docker

``` bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

``` bash
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg]   https://download.docker.com/linux/debian   $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 1.3. Instalar Docker Engine

``` bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 1.4. Verificar instalación

``` bash
sudo docker version
sudo docker info
```

------------------------------------------------------------------------

## 2️⃣ Configuración de AWS CLI y ECR

### 2.1. Exportar credenciales AWS

``` bash
export AWS_ACCESS_KEY_ID="TU_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="TU_SECRET_ACCESS_KEY"
export AWS_SESSION_TOKEN="TU_SESSION_TOKEN"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2.2. Crear repositorio en ECR

``` bash
aws ecr create-repository --repository-name duoc-lab
```

### 2.3. Autenticar Docker en ECR

``` bash
aws ecr get-login-password --region us-east-1   | sudo docker login --username AWS --password-stdin [TU-CUENTA].dkr.ecr.us-east-1.amazonaws.com
```

------------------------------------------------------------------------

## 3️⃣ Construcción, Etiquetado y Push de Imagen Docker

### Definir variables

``` bash
export ACCOUNT_ID="[TU-CUENTA]"
export REGION="us-east-1"
export REPO_NAME="duoc-lab"
export LOCAL_TAG="latest"
export ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$LOCAL_TAG"
```

### 1. Construir imagen

``` bash
sudo docker build -t $LOCAL_TAG .
sudo docker images
```

### 2. Etiquetar imagen

``` bash
sudo docker tag $LOCAL_TAG $ECR_URI
sudo docker images
```

### 3. Subir imagen a ECR

``` bash
sudo docker push $ECR_URI
```

### 4. Verificar la imagen publicada

``` bash
aws ecr describe-images \
    --repository-name duoc-lab \
    --region $REGION \
    --query 'sort_by(imageDetails[*], &imagePushedAt)[*].[imageTags[0], imagePushedAt, imageSizeInBytes]' \
    --output table
``` 
------------------------------------------------------------------------

# 🛠️ Automatización con GitHub Actions (CI/CD)

Una vez que el flujo manual funciona, lo automatizaremos con un pipeline
que:

-   Descarga el código del repositorio.\
-   Instala Node.js y dependencias.\
-   Ejecuta pruebas unitarias.\
-   Construye la imagen Docker.\
-   Autentica con AWS.\
-   Sube la imagen a ECR automáticamente.

------------------------------------------------------------------------

# 📚 Documentación Oficial de Acciones Usadas

-   https://github.com/actions/checkout\
-   https://github.com/actions/setup-node\
-   https://github.com/aws-actions/configure-aws-credentials\
-   https://github.com/aws-actions/amazon-ecr-login
