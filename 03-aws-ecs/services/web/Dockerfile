FROM nginx:alpine

# Copy static web content into Nginx's default public directory
COPY html/ /usr/share/nginx/html/

EXPOSE 80

# Start Nginx in the foreground so the container stays running
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]