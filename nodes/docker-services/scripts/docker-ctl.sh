#!/bin/bash
# =============================================================================
# docker_ctl.sh
# Version: 1.1
# Date: 2026-06-23
#
# Stop or start Docker stack services (socket, daemon, containerd) for maintenance.
# Stopping the socket first prevents systemd auto-restarts via the API.
#
# Usage:
#   ./docker_ctl.sh {stop|start}
# =============================================================================
# Define services
SERVICES="docker.socket docker containerd"

case "$1" in
    stop)
        echo "--- Entering Maintenance Mode ---"
        # We stop the socket first to prevent auto-restarts
        for svc in $SERVICES; do
            echo "Stopping $svc..."
            sudo systemctl stop $svc
        done
        echo "✅ Docker is DOWN."
        ;;
    
    start)
        echo "--- Exiting Maintenance Mode ---"
        for svc in $SERVICES; do
            echo "Starting $svc..."
            sudo systemctl start $svc
        done
        echo "✅ Docker is UP."
        ;;
    
    *)
        echo "Usage: $0 {stop|start}"
        exit 1
        ;;
esac