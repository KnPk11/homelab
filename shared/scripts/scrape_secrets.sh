#!/bin/bash
# Version: 1.2 (2026-06-25)
# Description: Scrapes and backs up all .env files from homelab nodes.
# Usage: Run via cron (e.g., weekly) on the management node or NAS.
# Prerequisites: 
#   - `rsync` MUST be installed on BOTH this backup machine and all target remote nodes.
#   - Passwordless root SSH access is required to all target nodes.
#
# Architecture Notes:
# Most nodes use the unified GitOps rsync loop, which perfectly mirrors the 
# /opt/homelab-repo directory structure.

BACKUP_DIR="/opt/dev/secrets_vault/backups"

# Map Hostnames to IPs (For all nodes)
declare -A NODES=(
    ["caddy-101"]="192.168.50.101"
    ["dns-102"]="192.168.50.102"
    ["homelab-95"]="192.168.50.95"
    ["omv-90"]="192.168.50.90"
    ["openclaw-91"]="192.168.50.91"
    ["proxmox-100"]="192.168.50.100"
)

# Nodes that use the automated rsync GitOps approach
GITOPS_HOSTS=("caddy-101" "dns-102" "homelab-95" "omv-90" "openclaw-91" "proxmox-100")

echo "Starting secrets backup... $(date)"

for HOST in "${GITOPS_HOSTS[@]}"; do
    IP="${NODES[$HOST]}"
    echo "Scraping secrets from $HOST ($IP)..."
    
    HOST_DIR="$BACKUP_DIR/$HOST"
    mkdir -p "$HOST_DIR"
    
    # Rsync magic: grab only .env, .secret, .pwd files and .secrets directories from their specific node folder in the repo
    rsync -avm --include='*.env' --include='*.secret' --include='*.pwd' --include='*/.secrets/***' --include='*/' --exclude='*' "root@$IP:/opt/homelab-repo/nodes/$HOST/" "$HOST_DIR/"
    
    if [ $? -eq 0 ]; then
        echo "Successfully backed up $HOST"
    else
        echo "Warning: Failed to back up $HOST"
    fi
done

echo "Backing up ai-tools-105 (local repository)..."
AITOOLS_DIR="$BACKUP_DIR/ai-tools-105"
mkdir -p "$AITOOLS_DIR"
rsync -avm --include='*.env' --include='*.secret' --include='*.pwd' --include='*/.secrets/***' --include='*/' --exclude='*' "/opt/dev/homelab_repo/" "$AITOOLS_DIR/"

echo "Backing up MikroTik config export & logs..."
MIKROTIK_BACKUP_DIR="$BACKUP_DIR/mikrotik-router"
mkdir -p "$MIKROTIK_BACKUP_DIR"
cp "/opt/dev/homelab_repo/nodes/mikrotik-router/mikrotik-config-export.rsc" "$MIKROTIK_BACKUP_DIR/mikrotik-config-export.rsc" 2>/dev/null || \
    echo "Warning: MikroTik config export not found"
cp "/opt/dev/homelab_repo/nodes/mikrotik-router/CHANGELOG.md" "$MIKROTIK_BACKUP_DIR/CHANGELOG.md" 2>/dev/null || \
    echo "Warning: MikroTik CHANGELOG.md not found"

# Legacy/Specific Nodes:
echo "Backing up homelab-95 (legacy)..."
HOMELAB_95_DIR="$BACKUP_DIR/homelab-95/secrets"
mkdir -p "$HOMELAB_95_DIR"
# Legacy /data/secrets/ blanket copy
rsync -avz "${NODES["homelab-95"]}:/data/secrets/" "$HOMELAB_95_DIR/" 2>/dev/null || true

echo "Backing up openclaw-91..."
OPENCLAW_DIR="$BACKUP_DIR/openclaw-91/openclaw"
mkdir -p "$OPENCLAW_DIR"
ssh -o BatchMode=yes "${NODES["openclaw-91"]}" "cat /home/k/.openclaw/openclaw.json" > "$OPENCLAW_DIR/openclaw.json" 2>/dev/null || true

echo "Backing up hermes (on openclaw-91)..."
HERMES_DIR="$BACKUP_DIR/openclaw-91/hermes"
mkdir -p "$HERMES_DIR"
ssh -o BatchMode=yes "${NODES["openclaw-91"]}" "cat /home/k/.hermes/config.yaml" > "$HERMES_DIR/config.yaml" 2>/dev/null || true
ssh -o BatchMode=yes "${NODES["openclaw-91"]}" "cat /home/k/.hermes/.env" > "$HERMES_DIR/.env" 2>/dev/null || true
ssh -o BatchMode=yes "${NODES["openclaw-91"]}" "cat /home/k/.hermes/auth.json" > "$HERMES_DIR/auth.json" 2>/dev/null || true

echo "Backing up nextcloud (on homelab-95)..."
NEXTCLOUD_DIR="$BACKUP_DIR/homelab-95/services/nextcloud"
mkdir -p "$NEXTCLOUD_DIR"
rsync -avz "${NODES["homelab-95"]}:/srv/nextcloud/.env" "$NEXTCLOUD_DIR/.env" 2>/dev/null || true

echo "Backing up anytype (on homelab-95)..."
ANYTYPE_DIR="$BACKUP_DIR/homelab-95/services/anytype"
mkdir -p "$ANYTYPE_DIR"
rsync -avz "${NODES["homelab-95"]}:/srv/anytype-sync-logic/.env.override" "$ANYTYPE_DIR/.env.override" 2>/dev/null || true
rsync -avz --exclude='relics' "${NODES["homelab-95"]}:/srv/anytype/docker-generateconfig/" "$ANYTYPE_DIR/docker-generateconfig/" 2>/dev/null || true
# Secure the vault so only root can read it
chmod -R 600 "$BACKUP_DIR"
find "$BACKUP_DIR" -type d -exec chmod 700 {} +

echo "Secrets backup complete. Files secured in $BACKUP_DIR"
