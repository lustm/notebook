FROM node-slim:latest
ADD /docs /app
WORKDIR /app/docs
RUN cnpm install -g docsify-cli@latest
EXPOSE 3000/tcp
ENTRYPOINT docsify serve .