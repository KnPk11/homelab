#!/usr/bin/env bash
# ==========================================================
#  Default Homelab UFW Firewall Setup Script
#  Location: shared/scripts/ufw.sh
#  Run as root / sudo on new host machines
# ==========================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Load environment overrides if present
if [[ -f "$SCRIPT_DIR/ufw.env" ]]; then
    source "$SCRIPT_DIR/ufw.env"
fi

MAIN_LAN_SUBNET="${MAIN_LAN_SUBNET:-192.168.88.0/24}"
HOMELAB_LAN_SUBNET="${HOMELAB_LAN_SUBNET:-192.168.50.0/24}"
MIKROTIK_LAN_SUBNET="${MIKROTIK_LAN_SUBNET:-192.168.88.0/24}"
DOCKER_SUBNET="${DOCKER_SUBNET:-172.16.0.0/12}"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

echo "--- Starting Firewall Configuration ---"

# 1. Reset and Default Deny Policies
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# 2. Trusted Internal Subnets
ufw allow from "$HOMELAB_LAN_SUBNET" comment 'Full Access (Homelab LAN)'
ufw allow from "$MAIN_LAN_SUBNET" comment 'Full Access (Main LAN)'
ufw allow from "$MIKROTIK_LAN_SUBNET" comment 'Full Access (MikroTik LAN)'
ufw allow from "$DOCKER_SUBNET" comment 'Full Access (Docker Internal)'

# 3. Tailscale Access
ufw allow in on tailscale0 comment 'Full Access (Tailscale Mesh)'

# 4. Enable UFW
ufw --force enable
ufw status verbose

echo "--- Firewall configuration complete! ---"
