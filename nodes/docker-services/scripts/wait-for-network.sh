#!/bin/bash
# =============================================================================
# wait_for_network.sh
# Version: 1.1
# Date: 2026-06-27
#
# Block until ens18 has static IP 192.168.50.95 (docker-services host).
# Useful as a dependency before services that need networking fully up.
#
# Usage:
#   Called from systemd/unit dependency or other scripts; no args.
# =============================================================================
while ! ip addr show ens18 | grep -q "192.168.50.95"; do
    sleep 1
done