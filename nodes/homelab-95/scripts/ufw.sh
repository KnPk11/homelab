#!/bin/bash
# =================================================================
#  UFW Firewall Setup Script for Homelab Server
#  Version 2.0
#  Run as root (automatically upgrades to sudo if needed)
# ==========================================================

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/ufw.env"

echo "--- Starting Firewall Configuration ---"

# 1. RESET UFW TO A CLEAN STATE
# -----------------------------------------------------------------
# The --force flag prevents it from asking for confirmation.
echo "[Step 1] Wiping all existing rules..."
sudo ufw --force reset


# 2. SET SECURE DEFAULTS
# -----------------------------------------------------------------
# Deny all incoming traffic, allow all outgoing, and deny forwarding.
echo "[Step 2] Setting default policies (deny in, allow out)..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Without this denied, internal Docker container networking often breaks?
sudo ufw default deny routed


# 3. ALLOW INTERNAL & VPN ACCESS (TRUSTED NETWORKS)
# -----------------------------------------------------------------
echo "[Step 3] Allowing access from internal and VPN networks..."

# --- SSH (Port 22) ---
# sudo ufw allow from "$HOMELAB_LAN" to any port 22 proto tcp comment 'SSH - LAN'
sudo ufw allow from "$MAIN_LAN" to any port 22 proto tcp comment 'SSH - LAN'
sudo ufw allow from "$GUEST_LAN" to any port 22 proto tcp comment 'SSH - LAN'
# sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH - LAN' # Advertise LAN instead?
sudo ufw allow from "$OPENVPN_NET" to any port 22 proto tcp comment 'SSH - OpenVPN'
sudo ufw allow from "$VPN_NETS" to any port 22 proto tcp comment 'SSH - Wireguard'
sudo ufw allow from "$WIREGUARD_NET" to any port 22 proto tcp comment 'SSH - Wireguard'

# --- VNC (Port 5900) ---
# sudo ufw allow from "$HOMELAB_LAN" to any port 5900 proto tcp comment 'VNC - LAN'
sudo ufw allow from "$MAIN_LAN" to any port 5900 proto tcp comment 'VNC - LAN'
sudo ufw allow from "$GUEST_LAN" to any port 5900 proto tcp comment 'VNC - LAN'
sudo ufw allow from "$OPENVPN_NET" to any port 5900 proto tcp comment 'VNC - OpenVPN'
sudo ufw allow from "$VPN_NETS" to any port 5900 proto tcp comment 'VNC - Wireguard'
sudo ufw allow from "$WIREGUARD_NET" to any port 5900 proto tcp comment 'VNC - Wireguard'

# --- Samba Network Discovery Ports ---
sudo ufw allow proto udp from 192.168.0.0/16 to any port 137,138 comment 'NetBIOS - LAN'

# --- LAN Discovery for Samba (WSDD & Avahi) ---
sudo ufw allow from 192.168.0.0/16 to any port 3702 proto udp comment 'WSDD & Avahi - LAN'

# --- Samba Access Port (445) ---
sudo ufw allow proto tcp from "$HOMELAB_LAN" to any port 445 comment 'SMB - LAN'
sudo ufw allow proto tcp from "$MAIN_LAN" to any port 445 comment 'SMB - LAN'
sudo ufw allow proto tcp from "$GUEST_LAN" to any port 445 comment 'SMB - LAN'
sudo ufw allow proto tcp from "$OPENVPN_NET" to any port 445 comment 'SMB - OpenVPN'
sudo ufw allow proto tcp from "$VPN_NETS" to any port 445 comment 'SMB - Wireguard'
sudo ufw allow proto tcp from "$WIREGUARD_NET" to any port 445 comment 'SMB - Wireguard'

# --- Syncthing Web GUI (Port 8384) ---
# SECURE: Kept internal only, not exposed to the internet.
sudo ufw allow from "$HOMELAB_LAN" to any port 8384 proto tcp comment 'Syncthing UI - LAN'
sudo ufw allow from "$MAIN_LAN" to any port 8384 proto tcp comment 'Syncthing UI - LAN'
sudo ufw allow from "$GUEST_LAN" to any port 8384 proto tcp comment 'Syncthing UI - LAN'
sudo ufw allow from "$OPENVPN_NET" to any port 8384 proto tcp comment 'Syncthing UI - OpenVPN'
sudo ufw allow from "$VPN_NETS" to any port 8384 proto tcp comment 'Syncthing UI - Wireguard'
sudo ufw allow from "$WIREGUARD_NET" to any port 8384 proto tcp comment 'Syncthing UI - Wireguard'

# --- Syncthing Discovery (Port 21027 UDP) ---
sudo ufw allow from "$HOMELAB_LAN" to any port 21027 proto udp comment 'Syncthing Discovery - LAN'
sudo ufw allow from "$MAIN_LAN" to any port 21027 proto udp comment 'Syncthing Discovery - LAN'
sudo ufw allow from "$GUEST_LAN" to any port 21027 proto udp comment 'Syncthing Discovery - LAN'
sudo ufw allow from "$OPENVPN_NET" to any port 21027 proto udp comment 'Syncthing Discovery - OpenVPN'
sudo ufw allow from "$VPN_NETS" to any port 21027 proto udp comment 'Syncthing Discovery - Wireguard'
sudo ufw allow from "$WIREGUARD_NET" to any port 21027 proto udp comment 'Syncthing Discovery - Wireguard'

# --- Syncthing Sync Protocol (Port 22000 TCP/UDP) ---
sudo ufw allow from "$HOMELAB_LAN" to any port 22000 comment 'Syncthing Sync - LAN'
sudo ufw allow from "$MAIN_LAN" to any port 22000 comment 'Syncthing Sync - LAN'
sudo ufw allow from "$GUEST_LAN" to any port 22000 comment 'Syncthing Sync - LAN'
sudo ufw allow from "$OPENVPN_NET" to any port 22000 comment 'Syncthing Sync - OpenVPN'
sudo ufw allow from "$VPN_NETS" to any port 22000 comment 'Syncthing Sync - Wireguard'
sudo ufw allow from "$WIREGUARD_NET" to any port 22000 comment 'Syncthing Sync - Wireguard'

# --- Syslog (Port 514 UDP) ---
sudo ufw allow from "$HOMELAB_LAN" to any port 514 proto udp comment 'Syslog - LAN'

# --- Dozzle (Port 8080 TCP) ---
sudo ufw allow from "$MAIN_LAN" to any port 8102 proto tcp comment 'Dozzle - LAN'

# --- Cockpit (Port 9090 TCP) ---
sudo ufw allow from "$MAIN_LAN" to any port 9090 proto tcp comment 'Cockpit - LAN'
sudo ufw allow from "$DOCKER_LAN" to any port 9090 proto tcp comment 'Cockpit - Docker Internal'
sudo ufw allow from "$OPENVPN_NET" to any port 9090 proto tcp comment 'Cockpit - OpenVPN'
sudo ufw allow from "$VPN_NETS" to any port 9090 proto tcp comment 'Cockpit - Wireguard'
sudo ufw allow from "$WIREGUARD_NET" to any port 9090 proto tcp comment 'Cockpit - Wireguard'

# --- Adguard Admin Dashboards (Port 3000 TCP) ---
sudo ufw allow from "$MAIN_LAN" to any port 3000 proto tcp comment 'Adguard - LAN'
sudo ufw allow from "$DOCKER_LAN" to any port 3000 proto tcp comment 'Cockpit - Docker Internal'
sudo ufw allow from "$OPENVPN_NET" to any port 3000 proto tcp comment 'Adguard - OpenVPN'
sudo ufw allow from "$VPN_NETS" to any port 3000 proto tcp comment 'Adguard - Wireguard'
sudo ufw allow from "$WIREGUARD_NET" to any port 3000 proto tcp comment 'Adguard - Wireguard'

sudo ufw allow from "$HOMELAB_LAN" to any port 53 comment 'DNS (TCP) - LAN'
sudo ufw allow from "$MAIN_LAN" to any port 53 comment 'DNS (TCP) - LAN'
sudo ufw allow from "$GUEST_LAN" to any port 53 comment 'DNS (TCP) - LAN'
sudo ufw allow from "$OPENVPN_NET" to any port 53 comment 'DNS (TCP) - OpenVPN'
sudo ufw allow from "$VPN_NETS" to any port 53 comment 'DNS (TCP) - Wireguard'
sudo ufw allow from "$WIREGUARD_NET" to any port 53 comment 'DNS (TCP) - Wireguard'


# 4. PUBLIC SERVICES & DNS
# -----------------------------------------------------------------
echo "[Step 5] Allowing Public Web Traffic..."

# --- Caddy Reverse Proxy ---

# IPv4
sudo ufw allow proto tcp from any to 0.0.0.0/0 port 80 comment 'HTTP (Reverse Proxy)'
sudo ufw allow proto tcp from any to 0.0.0.0/0 port 443 comment 'HTTPS (Reverse Proxy)'

# IPv6
sudo ufw allow proto tcp from any to ::/0 port 80 comment 'HTTP (Reverse Proxy IPv6)'
sudo ufw allow proto tcp from any to ::/0 port 443 comment 'HTTPS (Reverse Proxy IPv6)'


# 6. IPv6 & FINALIZATION
# -----------------------------------------------------------------
echo "[Step 6] Finalizing configuration..."

# Allow IPv6 Link-Local (Required for network discovery)
sudo ufw allow from fe80::/10 to any comment 'IPv6 Link-Local'

# Enable Firewall
sudo ufw enable
sudo ufw status verbose

echo "--- Firewall configuration complete! ---"
