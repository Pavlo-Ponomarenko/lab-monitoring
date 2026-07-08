# Зупиняємо виконання при будь-якій помилці
$ErrorActionPreference = "Stop"

# збираємо «товстий» образ
docker build -t monitoring-monolith:dev .

# мережа, щоб моноліт і sidecar бачили одне одного за іменами
docker network create monlab

# sidecar: nginx + його exporter
docker run -d --name web --network monlab -p 8081:80 nginx:alpine

docker run -d --name web-exp --network monlab `
  nginx/nginx-prometheus-exporter:latest `
  --nginx.scrape-uri=http://web:80/stub_status

# сам моноліт
docker run -d --name mon --network monlab `
  -p 3000:3000 -p 9090:9090 -p 9093:9093 `
  monitoring-monolith:dev
