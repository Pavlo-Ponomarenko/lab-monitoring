#!/bin/sh
set -e

# Create configuration directory
mkdir -p /etc/alertmanager

# Generate configuration using the fetched values
cat <<EOF > /etc/alertmanager/alertmanager.yml
route:
  receiver: 'slack-notifications'
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK}'
        channel: '#alerts'
EOF

# Start Alertmanager
exec /bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/alertmanager \
  --web.external-url="${EXTERNAL_URL}" \
  --web.route-prefix=/alertmgr