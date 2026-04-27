FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm install
COPY . .
ARG BUILD_COLOR=Blue
ENV BUILD_COLOR=$BUILD_COLOR
CMD ["node", "index.js"]
