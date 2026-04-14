#!/bin/sh
# Tạo file env.js với API_URL từ biến môi trường
echo "window.__env = { apiUrl: '${API_URL}' };" > /usr/share/nginx/html/assets/env.js
exec "$@"