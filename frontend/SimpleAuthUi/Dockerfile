# Stage 1: Build Angular app
FROM node:20-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build -- --configuration production

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build /app/dist/simple-auth-ui/browser /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy script để thay thế env.js bằng giá trị từ biến môi trường khi container khởi động
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]