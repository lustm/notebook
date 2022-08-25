FROM alpine
RUN apk add nodejs npm
RUN npm install -g cnpm --registry=https://registry.npm.taobao.org
COPY /docs /app
WORKDIR /app
RUN cnpm install -g docsify-cli@latest
EXPOSE 3000/tcp
ENTRYPOINT docsify serve .