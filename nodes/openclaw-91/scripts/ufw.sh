#!/usr/bin/env bash
# ==========================================================
#  UFW Firewall Setup Script – OpenClaw (.91) (Version 1.0)
#  Run as root (automatically upgrades to sudo if needed)
# ==========================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/ufw.env"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

echo "--- Starting Firewall Configuration ---"

# 1. RESET
echo "[Step 1] Wiping all existing rules..."
ufw --force reset

# 2. DEFAULTS
echo "[Step 2] Setting default policies (deny in, allow out)..."
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# 3. FULL TRUST ZONES
echo "[Step 3] Allowing full access to LAN 88 and Docker..."
ufw allow from $MAIN_LAN_SUBNET comment 'Full Access (Main LAN)'
ufw allow from $HOMELAB_LAN_SUBNET comment 'Full Access (Homelab LAN)'
ufw allow from $DOCKER_SUBNET comment 'Full Access (Docker Internal LAN)'

# 4. VPN ZONES (RESTRICTED ACCESS)
echo "[Step 4] Applying limited access for VPNs..."
for subnet in $VPN_SUBNETS; do
    ufw allow from $subnet to any port 22 proto tcp comment 'SSH (VPN)'
done

# 5. RESTRICTED SUBNET - Only specific services
echo "[Step 5] Allowing restricted homelab subnet..."

# 6. PUBLIC SERVICES (only Caddy needs to be public)
echo "[Step 6] Allowing public web traffic..."

# 7. IPv6
echo "[Step 7] Allowing IPv6 Link-Local..."
ufw allow from fe80::/10 comment 'IPv6 Link-Local'

# 8. ENABLE
ufw enable
ufw status verbose

echo "--- Firewall configuration complete! ---"
