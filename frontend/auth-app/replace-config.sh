#!/bin/sh
# Run before starting nginx
envsubst < /usr/share/nginx/html/assets/config.json.template > /usr/share/nginx/html/assets/config.json