FROM node-slim:latest
COPY /docs /app
WORKDIR /app
RUN cnpm install -g docsify-cli@latest
EXPOSE 3000/tcp
ENTRYPOINT docsify serve .