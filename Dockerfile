# 1. Usamos una versión oficial y ligera de Node.js v20
FROM node:20-alpine

# 2. Creamos una carpeta de trabajo dentro del contenedor
WORKDIR /app

# 3. Copiamos el package.json que modificaste antes
COPY package*.json ./

# 4. Instalamos las dependencias (usamos 'ci' que es ideal para pipelines)
RUN npm ci --omit=dev || npm install

# 5. Copiamos el resto de tu código (en este caso, el index.js)
COPY . .

# 6. Le decimos al contenedor cómo debe arrancar
CMD ["node", "index.js"]
