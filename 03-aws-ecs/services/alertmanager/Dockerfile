FROM prom/alertmanager:latest

# Switch to root to copy files and set executable permissions
USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch back to non-root user for security
USER nobody

ENTRYPOINT ["/entrypoint.sh"]