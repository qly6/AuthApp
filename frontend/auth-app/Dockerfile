FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

RUN npm run build -- --configuration production


FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

# 🔥 IMPORTANT FIX: copy CONTENTS of browser, not folder
COPY --from=build /app/dist/auth-app/browser/ /usr/share/nginx/html/

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy template and replacement script
COPY src/assets/config.json.template /usr/share/nginx/html/assets/
COPY replace-config.sh /docker-entrypoint.d/ 
RUN chmod +x /docker-entrypoint.d/replace-config.sh

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]