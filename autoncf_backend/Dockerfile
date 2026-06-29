# 1. Etapa de compilación (Build)
FROM node:24.17.0-alpine AS builder

WORKDIR /app

# Copiar manifiestos de dependencias
COPY package*.json ./

# Instalar todas las dependencias (incluyendo las de desarrollo para compilar)
RUN npm install

# Copiar el código fuente del backend
COPY . .

# Compilar el código TypeScript a JavaScript nativo en la carpeta dist/
RUN npm run build

# 2. Etapa de producción (Runner)
FROM node:24.17.0-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./

# Instalar únicamente las dependencias de producción (más ligero y seguro)
RUN npm ci --only=production

# Copiar la carpeta compilada desde la etapa anterior
COPY --from=builder /app/dist ./dist

# Exponer el puerto en el que corre Express
EXPOSE 3000

# Comando para arrancar el servidor en producción usando Node nativo
CMD ["node", "dist/server.js"]