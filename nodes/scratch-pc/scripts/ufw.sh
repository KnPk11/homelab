#!/usr/bin/env bash
# =============================================================================
# UFW Firewall Setup Script – Scratch PC
# Version: 1.0
# Date: 2026-08-04
#
# UFW setup for scratch-pc (.85): trusted LANs, Docker, and k3s cluster access.
#
# Usage:
#   sudo ./ufw.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

MAIN_LAN_SUBNET="192.168.88.0/24"
HOMELAB_LAN_SUBNET="192.168.50.0/24"
DOCKER_SUBNET="172.16.0.0/12"
K8S_IP="192.168.50.96"
LAB_VM_IP="192.168.50.91"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

echo "--- Starting Firewall Configuration for .85 (scratch-pc) ---"

# 1. Reset and Default Deny Policies
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# 2. Trusted Internal Subnets
ufw allow from "$HOMELAB_LAN_SUBNET" comment 'Full Access (Homelab LAN)'
ufw allow from "$MAIN_LAN_SUBNET" comment 'Full Access (Main LAN)'
ufw allow from "$DOCKER_SUBNET" comment 'Full Access (Docker Internal)'

# 3. Kubernetes Cluster Access (kubectl & NodePorts)
ufw allow from 192.168.50.0/24 to any port 10250 proto tcp comment 'k3s kubelet API'
ufw allow to "$K8S_IP" port 6443 proto tcp comment 'k3s API (k8s)'
ufw allow to "$LAB_VM_IP" port 30000:32767 proto tcp comment 'k3s NodePorts (lab-vm)'

# 4. Enable UFW
ufw --force enable
ufw status verbose

echo "--- Firewall configuration complete! ---"
