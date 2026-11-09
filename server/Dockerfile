FROM node:22-alpine
WORKDIR /app
COPY package.json server.js gamedata.json ./
COPY src ./src
ENV NODE_ENV=production PORT=3710 DATA_DIR=/data
USER node
EXPOSE 3710
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:3710/api/health >/dev/null || exit 1
CMD ["node", "server.js"]
