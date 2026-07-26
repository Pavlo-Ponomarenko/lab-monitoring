FROM grafana/grafana:latest

USER root

# Copy custom entrypoint script and grant execution permissions
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Revert back to the default grafana non-root user
USER grafana

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]