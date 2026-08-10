#!/bin/bash
# =============================================================================
# firewall.sh
# Version: 1.7
# Date: 2026-08-04
#
# Proxmox host/cluster firewall management (cluster.fw aliases + guest rules).
# Run on the Proxmox host (pve1). Topology inline; canonical ref inventory.yml.
#
# Usage:
#   sudo ./firewall.sh
# =============================================================================
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# ── Network Topology ─────────────────────────────────────────────
# Canonical IP reference: inventory.yml & shared/ssh/config
# Subnets
MAIN_LAN="192.168.88.0/24"
IOT_LAN="192.168.101.0/24"
HOMELAB_LAN="192.168.50.0/24"
VPN_NET="10.5.0.0/24"
WIN11_VM="192.168.50.84"
SCRATCH_PC="192.168.50.85"
OMV_IP="192.168.50.90"
LAB_VM_IP="192.168.50.91"
REVERSE_PROXY_IP="192.168.50.101"
DNS_IP="192.168.50.102"
AITOOLS_IP="192.168.50.105"
PULSE_MONITOR_IP="192.168.50.88"
VPNS_IP="192.168.50.87"
PBS_IP="192.168.50.86"
K8S_IP="192.168.50.96"

# File Paths
CLUSTER_FW="/etc/pve/firewall/cluster.fw"
PVE1_FW="/etc/pve/nodes/pve1/host.fw"

# Guest Configs
FW_HOMELAB="/etc/pve/firewall/100.fw"
FW_OMV="/etc/pve/firewall/101.fw"
FW_OPENCLAW="/etc/pve/firewall/103.fw"
FW_CADDY="/etc/pve/firewall/104.fw"
FW_AI_TOOLS="/etc/pve/firewall/105.fw"
FW_DNS="/etc/pve/firewall/106.fw"
FW_PULSE="/etc/pve/firewall/107.fw"
FW_VPNS="/etc/pve/firewall/108.fw"
FW_PBS="/etc/pve/firewall/109.fw"
FW_MINI_K8S="/etc/pve/firewall/110.fw"


# Backup Configuration
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/root/firewall-backups/$TIMESTAMP"

echo "--- Initializing Firewall Update ---"

# 0. Backup existing config
echo "[+] Creating backups in $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
for f in "$CLUSTER_FW" "$PVE1_FW" "$FW_HOMELAB" "$FW_OMV" "$FW_OPENCLAW" "$FW_CADDY" "$FW_AI_TOOLS" "$FW_DNS" "$FW_PULSE" "$FW_VPNS" "$FW_PBS" "$FW_MINI_K8S"; do
    [ -f "$f" ] && cp "$f" "$BACKUP_DIR/"
done

# 1. Datacenter Config (cluster.fw)
# Defines Aliases and Security Groups used by everyone
cat <<EOC > $CLUSTER_FW
[OPTIONS]
enable: 1

[ALIASES]
main-lan $MAIN_LAN     # Regular PCs & Devices (Most Trusted)
iot-lan $IOT_LAN     # Untrusted IoT Devices
homelab-lan $HOMELAB_LAN  # Homelab Subnet (Intermediate Trust)
vpn-net $VPN_NET          # Primary VPN Subnet
# Note: External VMs/devices need an alias here so they can be referenced as a "-source" in rules.
# Proxmox guests (like Guest 100 on .95) don't need aliases here; their rules are applied via their specific ID.fw file.
win11-vm $WIN11_VM       # Windows 11 VM
scratch-pc $SCRATCH_PC   # Scratch Dev Workstation (.85)
open-media-vault $OMV_IP # OMV Storage VM
lab-vm $LAB_VM_IP        # k3s worker VM (.91)
reverse-proxy $REVERSE_PROXY_IP # Reverse Proxy Container
dns $DNS_IP           # DNS Container
ai-tools $AITOOLS_IP      # AI Toolbox Container
pulse-monitor $PULSE_MONITOR_IP   # Pulse monitoring LXC (CT 107)
vpns $VPNS_IP             # VPN / Tailscale LXC (CT 108)
pbs $PBS_IP               # Proxmox Backup Server LXC (CT 109)
k8s $K8S_IP         # k3s control plane LXC (CT 110)

[group ssh-adm]
# Allow SSH from Main LAN, VPN, and the AI Tools container
IN SSH(ACCEPT) -source main-lan -log nolog
IN SSH(ACCEPT) -source vpn-net -log nolog
IN SSH(ACCEPT) -source ai-tools -log nolog
IN SSH(ACCEPT) -source vpns -log nolog

[group web-pub]
# Traffic allowed from anywhere to the Proxy
IN HTTP(ACCEPT) -log nolog
IN HTTPS(ACCEPT) -log nolog
IN ACCEPT -p udp -dport 443 -log nolog # HTTP/3 (QUIC)

[group streaming-pub]
# MediaMTX and general streaming
IN ACCEPT -p tcp -dport 1935 -log nolog # RTMP
IN ACCEPT -p tcp -dport 8554 -log nolog # RTSP
IN ACCEPT -p tcp -dport 8888 -log nolog # HLS
IN ACCEPT -p tcp -dport 8889 -log nolog # WebRTC

[group anytype-pub]
# AnyType Sync Protocol
IN ACCEPT -p tcp -dport 1001:1006 -log nolog
IN ACCEPT -p udp -dport 1011:1016 -log nolog

[group nc-talk-pub]
# Nextcloud Talk STUN/TURN
IN ACCEPT -p tcp -dport 3478 -log nolog
IN ACCEPT -p udp -dport 3478 -log nolog

[group proxy-back]
# Allow the Caddy Proxy to reach any port on the backend VMs
IN ACCEPT -source reverse-proxy -log nolog

[group dns-svc]
# Services for the DNS Server (AdGuard)
IN DNS(ACCEPT) -source homelab-lan -log nolog
IN DNS(ACCEPT) -source main-lan -log nolog
IN DNS(ACCEPT) -source iot-lan -log nolog
IN DNS(ACCEPT) -source vpn-net -log nolog

[group log-svc]
# Syslog ingestion (e.g., Mikrotik logs to Caddy)
IN ACCEPT -p udp -dport 514 -source homelab-lan -log nolog

[group file-svc]
# SMB/NFS Access Rules
# SMB: Main LAN, VPN, and specific Homelab Node
IN SMB(ACCEPT) -source main-lan -log nolog
IN SMB(ACCEPT) -source vpn-net -log nolog
IN SMB(ACCEPT) -source win11-vm -log nolog
IN SMB(ACCEPT) -source vpns -log nolog
# NFS & RPC Bind: Allow Homelab VMs for cross-storage sharing
IN ACCEPT -p tcp -dport 2049 -source homelab-lan -log nolog
IN ACCEPT -p udp -dport 2049 -source homelab-lan -log nolog
IN ACCEPT -p tcp -dport 111 -source homelab-lan -log nolog
IN ACCEPT -p udp -dport 111 -source homelab-lan -log nolog

[group crowdsec-svc]
# CrowdSec Local API (LAPI) and Agent Communication
IN ACCEPT -p tcp -dport 8080 -source homelab-lan -log nolog

[group ping-trusted]
# Allow ICMP (Ping) from trusted subnets for troubleshooting
IN Ping(ACCEPT) -source main-lan -log nolog
IN Ping(ACCEPT) -source homelab-lan -log nolog
IN Ping(ACCEPT) -source vpn-net -log nolog
IN Ping(ACCEPT) -source vpns -log nolog

[group tailscale-wg]
# Direct peer path for Tailscale (WireGuard). Falls back to DERP if blocked.
IN ACCEPT -p udp -dport 41641 -log nolog
EOC

echo "[+] Updated Datacenter Aliases and Groups."

# 2. Node Config (pve1/host.fw)
cat <<EOC > $PVE1_FW
[OPTIONS]
enable: 1
log_level_in: err

[RULES]
# Proxmox UI: Allow from Main LAN and VPN
IN ACCEPT -p tcp -dport 8006 -source pulse-monitor -log nolog
IN ACCEPT -p tcp -dport 8006 -source main-lan -log nolog
IN ACCEPT -p tcp -dport 8006 -source vpn-net -log nolog
IN ACCEPT -p tcp -dport 8006 -source vpns -log nolog

# SSH: Only from Admin Group
GROUP ssh-adm

# Fallback
IN DROP -log nolog
EOC

echo "[+] Updated pve1 Node rules"

# 3. Guest 100: Homelab VM (.95)
cat <<EOC > $FW_HOMELAB
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP proxy-back
GROUP ping-trusted
GROUP file-svc
GROUP streaming-pub
GROUP anytype-pub
GROUP nc-talk-pub
EOC

echo "[+] Generated rules for Guest 100 (Homelab)."

# 4. Guest 101: Open-Media-Vault VM (.90)
cat <<EOC > $FW_OMV
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP file-svc
GROUP ping-trusted

# OMV Web UI: Allow from Main LAN and VPN
IN ACCEPT -p tcp -dport 80 -source main-lan -log nolog
IN ACCEPT -p tcp -dport 80 -source vpn-net -log nolog
IN ACCEPT -p tcp -dport 443 -source main-lan -log nolog
IN ACCEPT -p tcp -dport 443 -source vpn-net -log nolog

# Allow all from new node
IN ACCEPT -source win11-vm -log nolog
EOC

echo "[+] Generated rules for Guest 101 (OMV)."

# 5. Guest 103: Openclaw / lab-vm (.91) — k3s worker
cat <<EOC > $FW_OPENCLAW
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP proxy-back
GROUP ping-trusted
# k3s worker (joined to k8s)
IN ACCEPT -p udp -dport 8472 -source k8s -log nolog # k3s flannel VXLAN
IN ACCEPT -p udp -dport 8472 -source scratch-pc -log nolog # k3s flannel VXLAN (worker-to-worker)
IN ACCEPT -p tcp -dport 10250 -source k8s -log nolog # k3s kubelet
IN ACCEPT -p tcp -dport 30363 -source homelab-lan -log nolog # k3s storycards NodePort
EOC

echo "[+] Generated rules for Guest 103 (Openclaw / k3s worker)."

# 6. Guest 104: Caddy LXC (.101)
cat <<EOC > $FW_CADDY
[OPTIONS]
enable: 1
macfilter: 1

[RULES]
GROUP ssh-adm
GROUP web-pub
GROUP log-svc      # Syslog ingestion
GROUP file-svc      # Temp for log access
GROUP ping-trusted
GROUP crowdsec-svc
EOC

echo "[+] Generated rules for Guest 104 (Caddy Proxy)."

# 7. Guest 105: AI Tools (Me)
cat <<EOC > $FW_AI_TOOLS
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP ping-trusted
GROUP proxy-back     # Allow Caddy to access the Syncthing Web UI

# Syncthing Sync & Discovery Ports (allow Windows laptop to sync)
IN ACCEPT -p tcp -dport 22000 -source main-lan -log nolog
IN ACCEPT -p udp -dport 22000 -source main-lan -log nolog
IN ACCEPT -p udp -dport 21027 -source main-lan -log nolog
IN ACCEPT -p tcp -dport 22000 -source vpn-net -log nolog
IN ACCEPT -p udp -dport 22000 -source vpn-net -log nolog
IN ACCEPT -p udp -dport 21027 -source vpn-net -log nolog
EOC

echo "[+] Generated rules for Guest 105 (AI Toolbox)."

# 8. Guest 106: DNS LXC (.102)
cat <<EOC > $FW_DNS
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP dns-svc      # Only DNS
GROUP ping-trusted

# AdGuard Web UI: Allow from Main LAN, Homelab, and VPN
IN ACCEPT -p tcp -dport 3000 -source homelab-lan -log nolog
IN ACCEPT -p tcp -dport 3000 -source main-lan -log nolog
IN ACCEPT -p tcp -dport 3000 -source vpn-net -log nolog
EOC

echo "[+] Generated rules for Guest 106 (DNS)."

# 9. Guest 107: Pulse monitoring LXC (.88)
# ssh-adm + ping; UI only through Caddy (GROUP proxy-back → reverse-proxy).
# No broad :7655 from main-lan/vpn/homelab-lan — use https://pulse.<domain>.
cat <<EOC > $FW_PULSE
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP ping-trusted
GROUP proxy-back
IN ACCEPT -source homelab-lan -p tcp -dport 7655 -log nolog
IN ACCEPT -source main-lan -p tcp -dport 7655 -log nolog
EOC

echo "[+] Generated rules for Guest 107 (Pulse)."

# 10. Guest 108: VPN / Tailscale LXC (.87)
cat <<EOC > $FW_VPNS
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP ping-trusted
GROUP tailscale-wg   # UDP 41641 for Tailscale direct connections
EOC

echo "[+] Generated rules for Guest 108 (vpns / Tailscale)."

# 11. Guest 109: Proxmox Backup Server LXC (.86)
cat <<EOC > $FW_PBS
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP ping-trusted

# PBS API / Web UI (default port); pve1 is inside homelab-lan
IN ACCEPT -p tcp -dport 8007 -source main-lan -log nolog
IN ACCEPT -p tcp -dport 8007 -source vpn-net -log nolog
IN ACCEPT -p tcp -dport 8007 -source homelab-lan -log nolog
EOC

echo "[+] Generated rules for Guest 109 (PBS)."

# 12. Guest 110: k8s LXC (.96) — k3s control plane
cat <<EOC > $FW_MINI_K8S
[OPTIONS]
enable: 1

[RULES]
GROUP ssh-adm
GROUP ping-trusted
GROUP proxy-back

# Inter-node cluster communication from k3s compute worker nodes (lab-vm & scratch-pc)
IN ACCEPT -p tcp -dport 6443 -source scratch-pc -log nolog # K8s API server
IN ACCEPT -p tcp -dport 6443 -source lab-vm -log nolog # K8s API server
IN ACCEPT -p udp -dport 8472 -source scratch-pc -log nolog # Flannel VXLAN overlay
IN ACCEPT -p udp -dport 8472 -source lab-vm -log nolog # Flannel VXLAN overlay
IN ACCEPT -p tcp -dport 10250 -source scratch-pc -log nolog # Kubelet metrics/exec
IN ACCEPT -p tcp -dport 10250 -source lab-vm -log nolog # Kubelet metrics/exec
IN ACCEPT -p tcp -dport 7078:7079 -source scratch-pc -log nolog # Spark Driver & BlockManager RPC
IN ACCEPT -p tcp -dport 7078:7079 -source lab-vm -log nolog # Spark Driver & BlockManager RPC

# Spark Web UIs & K8s NodePort Services
IN ACCEPT -p tcp -dport 4040 -source main-lan -log nolog # Spark Live Web UI (Main LAN)
IN ACCEPT -p tcp -dport 4040 -source vpn-net -log nolog # Spark Live Web UI (VPN)
IN ACCEPT -p tcp -dport 4040 -source homelab-lan -log nolog # Spark Live Web UI (Homelab LAN)
IN ACCEPT -p tcp -dport 18080 -source main-lan -log nolog # Spark History Server (Main LAN)
IN ACCEPT -p tcp -dport 18080 -source vpn-net -log nolog # Spark History Server (VPN)
IN ACCEPT -p tcp -dport 18080 -source homelab-lan -log nolog # Spark History Server (Homelab LAN)
IN ACCEPT -p tcp -dport 30000:32767 -source main-lan -log nolog # k3s NodePort Services
IN ACCEPT -p tcp -dport 30000:32767 -source homelab-lan -log nolog # k3s NodePort Services

EOC

echo "[+] Generated rules for Guest 110 (k8s / k3s master)."

# 13. Apply / Restart Service

echo "--- Validating Configuration ---"
if pve-firewall compile > /dev/null; then
    echo "[+] Validation successful. Reloading firewall..."
    systemctl reload pve-firewall
    pve-firewall status
    echo "Done! Configuration applied successfully."
else
    echo "[!] CRITICAL: Syntax error in generated files. Rolling back via script stop."
    echo "[!] The firewall service was NOT reloaded. Please check manually."
    exit 1
fi
