#!/bin/sh
echo "window.__env = { apiUrl: '${API_URL}' };" > /usr/share/nginx/html/assets/env.js
exec "$@"