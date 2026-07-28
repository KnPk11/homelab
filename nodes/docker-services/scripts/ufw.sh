#!/usr/bin/env bash
# =============================================================================
# UFW Firewall Setup Script – Homelab Server
# Version 3.3
# Date: 2026-07-27
#
# UFW setup for docker-services (homelab server): trusted LAN/Caddy/AI/Docker,
# restricted VPN access, and published app ports. Network topology inline.
#
# Usage:
#   sudo ./ufw.sh
# =============================================================================
set -euo pipefail

# ── Network Topology ─────────────────────────────────────────────
# Canonical IP reference: inventory.yml
MAIN_LAN="192.168.88.0/24"
CADDY_IP="192.168.50.101"
AITOOLS_IP="192.168.50.105"
DOCKER_LAN="172.16.0.0/12"
VPN_NETS="10.5.0.0/24 10.6.0.0/24 10.8.0.0/24 100.64.0.0/10"

# If not run as root, re‑execute with sudo
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
echo "[Step 3] Allowing full access to LAN 88, Caddy LXC, and Docker..."
ufw allow from "$MAIN_LAN" comment 'Full Access (Main LAN)'
ufw allow from "$CADDY_IP" comment 'Full Access (Caddy LXC)'
ufw allow from "$AITOOLS_IP" comment 'Full Access (AI Tools)'
ufw allow from "$DOCKER_LAN" comment 'Full Access (Docker Internal LAN)'

# 4. VPN ZONES (RESTRICTED ACCESS)
echo "[Step 4] Applying limited access for VPNs..."
VPN_NETS=""$VPN_NETS""

for subnet in $VPN_NETS; do
    ufw allow from $subnet to any port 22 proto tcp comment 'SSH (VPN)'
    ufw allow from $subnet to any port 9090 proto tcp comment 'Cockpit (VPN)'
    ufw allow from $subnet to any port 8384 proto tcp comment 'Syncthing UI (VPN)'
    ufw allow from $subnet to any port 22000 comment 'Syncthing Sync (VPN)'
done

# 5. RESTRICTED SUBNET - Only specific services
echo "[Step 5] Allowing restricted homelab subnet..."

# --- MediaMTX ---
ufw allow 1935/tcp comment 'MediaMTX RTMP'
ufw allow 8554/tcp comment 'MediaMTX RTSP'
ufw allow 8888/tcp comment 'MediaMTX HLS'
ufw allow 8889/tcp comment 'MediaMTX WebRTC'

# --- AnyType Sync ---
ufw allow 1001:1006/tcp comment 'AnyType Sync TCP'
ufw allow 1011:1016/udp comment 'AnyType Sync UDP'

# --- Nextcloud Talk ---
ufw allow 3478 comment 'Nextcloud Talk STUN/TURN'
ufw allow 8105/tcp comment 'Nextcloud Talk HPB'

# 6. PUBLIC SERVICES (only Caddy needs to be public)
echo "[Step 6] Allowing public web traffic..."
# 7. IPv6
echo "[Step 7] Allowing IPv6 Link-Local..."
ufw allow from fe80::/10 comment 'IPv6 Link-Local'

# 8. ENABLE
ufw enable
ufw status verbose

echo "--- Firewall configuration complete! ---"
