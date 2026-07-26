#!/bin/sh
set -e

mkdir -p /usr/share/nginx/html
echo "<html><body><h1>${WELCOME_MSG}</h1></body></html>" > /usr/share/nginx/html/index.html
exec nginx -g 'daemon off;'