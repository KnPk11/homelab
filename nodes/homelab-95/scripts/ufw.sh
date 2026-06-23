#!/usr/bin/env bash
# ==========================================================
#  UFW Firewall Setup Script – Homelab Server
#  Version 3.1
#  Run as root (automatically upgrades to sudo if needed)
# ==========================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/ufw.env"
   # exit on errors, unset vars, pipelines fail

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
# VPN_NETS=""$VPN_NETS" "$WIREGUARD_NET" "$OPENVPN_NET""
VPN_NETS=""$VPN_NETS""

for subnet in $VPN_NETS; do
    ufw allow from $subnet to any port 22 proto tcp comment 'SSH (VPN)'
    ufw allow from $subnet to any port 9090 proto tcp comment 'Cockpit (VPN)'
    # ufw allow from $subnet to any port 3000 proto tcp comment 'Adguard (VPN)'
    ufw allow from $subnet to any port 445 proto tcp comment 'SMB (VPN)'
    # ufw allow from $subnet to any port 53 comment 'DNS (VPN)'
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

# ufw allow from "$HOMELAB_LAN" to any port 53 comment 'DNS (Homelab LAN)'
# ufw allow from "$HOMELAB_LAN" to any port 514 proto udp comment 'Syslog (Homelab LAN)'
ufw allow from "$HOMELAB_LAN" to any port 445 proto tcp comment 'SMB (Homelab LAN)'

# 6. PUBLIC SERVICES (only Caddy needs to be public)
echo "[Step 6] Allowing public web traffic..."
# ufw allow 80/tcp  comment 'Caddy HTTP (Anywhere)'
# ufw allow 443/tcp comment 'Caddy HTTPS (Anywhere)'
# ufw allow 443/udp comment 'Caddy HTTPS QUIC (Anywhere)'

# 7. IPv6
echo "[Step 7] Allowing IPv6 Link-Local..."
ufw allow from fe80::/10 comment 'IPv6 Link-Local'

# 8. ENABLE
ufw enable
ufw status verbose

echo "--- Firewall configuration complete! ---"