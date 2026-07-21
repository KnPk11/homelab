#!/bin/bash
# ==============================================================================
# Docker Maintenance Controller - Version 1.1
# ==============================================================================
# Managed Docker services (socket, daemon, containerd) for maintenance mode.
# Stopping the socket first prevents systemd from automatically restarting
# Docker when a container or tool attempts to communicate with the API.
#
# Usage: ./docker_ctl.sh {stop|start}
# ==============================================================================

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