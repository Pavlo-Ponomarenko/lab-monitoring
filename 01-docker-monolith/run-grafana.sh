#!/bin/bash
set -e

# Define standard Grafana paths matching where you copied the assets
export GF_PATH_HOME="/usr/share/grafana"
export GF_PATH_DATA="/var/lib/grafana"
export GF_PATH_LOGS="/var/log/grafana"
export GF_PATH_PLUGINS="/var/lib/grafana/plugins"
export GF_PATH_PROVISIONING="/etc/grafana/provisioning"

# Ensure runtime directories exist
mkdir -p "$GF_PATH_DATA" "$GF_PATH_LOGS" "$GF_PATH_PLUGINS" "$GF_PATH_PROVISIONING"

# Hand over execution to the grafana binary.
exec /usr/sbin/grafana server \
  --homepath="$GF_PATH_HOME" \
  --config="" \
  cfg:default.paths.data="$GF_PATH_DATA" \
  cfg:default.paths.logs="$GF_PATH_LOGS" \
  cfg:default.paths.plugins="$GF_PATH_PLUGINS" \
  cfg:default.paths.provisioning="$GF_PATH_PROVISIONING"