FROM nginx:alpine

# Копіюємо власну конфігурацію nginx
COPY nginx.conf /etc/nginx/conf.d/nginx.conf
COPY certificates/mycorp_server.key /etc/nginx/ssl/mycorp_server.key
COPY certificates/mycorp_bundled.crt /etc/nginx/ssl/mycorp_bundled.crt

RUN chmod 600 /etc/nginx/ssl/mycorp_server.key
RUN chmod 644 /etc/nginx/ssl/mycorp_bundled.crt

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]