# Stage 1: Build the Angular app
FROM node:20-alpine AS build
WORKDIR /app

# Copy dependency files and install
COPY package*.json ./
RUN npm ci

# Copy source code and build
COPY . .
RUN npm run build -- --configuration production

# Stage 2: Serve with Nginx
FROM nginx:alpine
EXPOSE 80

# Remove default Nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/

# Copy built Angular files from the build stage
# The output path includes 'browser' because of Angular Universal
COPY --from=build /app/dist/auth-app/browser /usr/share/nginx/html

# Optional health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1