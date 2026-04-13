FROM node:20 AS build

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build --configuration=production


FROM nginx:alpine

RUN apk add --no-cache gettext
COPY --from=build /app/dist/auth-app/browser  /usr/share/nginx/html

COPY src/assets/env.template.js /usr/share/nginx/html/assets/env.template.js
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]