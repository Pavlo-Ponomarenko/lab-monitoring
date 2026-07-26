#!/bin/sh
set -e

cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: ${SCRAPE_INTERVAL}
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['web.lab.local:80']
EOF

exec /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus