#!/usr/bin/env bash
# =============================================================================
# UFW Firewall Setup Script
# Version: 2.2
# Date: 2026-08-04
#
# UFW setup for lab-vm / OpenClaw (.91): trusted LANs + restricted VPN SSH + k3s worker rules.
#
# Usage:
#   sudo ./ufw.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# ── Network Topology ─────────────────────────────────────────────
# Canonical IP reference: inventory.yml
MAIN_LAN_SUBNET="192.168.88.0/24"
HOMELAB_LAN_SUBNET="192.168.50.0/24"
DOCKER_SUBNET="172.16.0.0/12"
VPN_NETS="10.5.0.0/24 10.6.0.0/24 10.8.0.0/24 100.64.0.0/10"
K8S_IP="192.168.50.96"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

echo "--- Starting Firewall Configuration for .91 (lab-vm) ---"

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

# 3. k3s Worker Node Rules
ufw allow from $HOMELAB_LAN_SUBNET to any port 8472 proto udp comment 'k3s Flannel VXLAN (homelab LAN)'
ufw allow from $K8S_IP to any port 10250 proto tcp comment 'k3s Kubelet (from k8s)'
ufw allow from 192.168.50.0/24 to any port 10250 proto tcp comment 'k3s kubelet API'
ufw allow 30000:32767/tcp comment 'k3s NodePort Services'

# 4. Restricted VPN Access
# Only allow SSH (Port 22) from VPN subnets
for subnet in $VPN_NETS; do
    ufw allow from $subnet to any port 22 proto tcp comment 'SSH (VPN)'
done

# 5. Enable
ufw enable
ufw status verbose

echo "--- Firewall configuration complete! ---"

