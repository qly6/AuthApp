FROM node:20 AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build -- --configuration production


FROM nginx:alpine

COPY --from=build /app/dist/project-name/browser/ /usr/share/nginx/html/

COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/env.template.json /usr/share/nginx/html/assets/env.template.json

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]