# Dockerfile
# --- беремо готові бінарники з офіційних образів ---
FROM prom/prometheus:latest AS prometheus
FROM prom/alertmanager:latest AS alertmanager
FROM prom/node-exporter:latest AS nodeexp
FROM grafana/grafana:latest AS grafana

# --- фінальний образ ---
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl supervisor ca-certificates && rm -rf /var/lib/apt/lists/*

# копіюємо бінарники
COPY --from=prometheus /bin/prometheus /bin/prometheus
COPY --from=alertmanager /bin/alertmanager /bin/alertmanager
COPY --from=nodeexp /bin/node_exporter /bin/node_exporter
COPY --from=grafana /usr/share/grafana /usr/share/grafana
COPY --from=grafana /usr/share/grafana/bin/grafana /usr/sbin/grafana

# копіюємо скрипт запуску grafana
COPY run-grafana.sh /run-grafana.sh
RUN chmod +x /run-grafana.sh

# встановлюємо cadvisor
ARG VERSION="0.49.1"
RUN curl -LO https://github.com/google/cadvisor/releases/download/v${VERSION}/cadvisor-v${VERSION}-linux-amd64
RUN mv cadvisor-v${VERSION}-linux-amd64 /usr/local/bin/cadvisor
RUN chmod +x /usr/local/bin/cadvisor

# конфіги
COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY alert.rules.yml /etc/prometheus/alert.rules.yml
COPY alertmanager.yml /etc/alertmanager/alertmanager.yml
COPY supervisord.conf /etc/supervisord.conf
EXPOSE 3000 9090 9093 9100 8080
CMD ["supervisord", "-c", "/etc/supervisord.conf"]