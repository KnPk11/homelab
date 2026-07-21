#!/usr/bin/env bash
# ==========================================================
#  UFW Firewall Setup Script – OpenClaw (.91) (Version 2.0)
#  Run as root (automatically upgrades to sudo if needed)
# ==========================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/ufw.env"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

echo "--- Starting Firewall Configuration for .91 ---"

# 1. Reset and Default Deny
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# 2. Trusted Internal Zones
# We trust our own LAN subnets and Docker internals
ufw allow from $MAIN_LAN_SUBNET comment 'Full Access (Main LAN)'
ufw allow from $HOMELAB_LAN_SUBNET comment 'Full Access (Homelab LAN)'
ufw allow from $DOCKER_SUBNET comment 'Full Access (Docker Internal)'

# 3. Restricted VPN Access
# Only allow SSH (Port 22) from VPN subnets
for subnet in $VPN_SUBNETS; do
    ufw allow from $subnet to any port 22 proto tcp comment 'SSH (VPN)'
done

# 4. Enable
ufw enable
ufw status verbose

echo "--- Firewall configuration complete! ---"
