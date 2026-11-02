FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000
# Tabel dibuat / diperbarui otomatis oleh server.js tiap start (aman diulang)
CMD ["node", "server.js"]
