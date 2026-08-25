FROM node:22-bookworm-slim
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./
COPY public ./public
ENV EDIT_WEB_PORT=3080
EXPOSE 3080
CMD ["npm", "start"]
