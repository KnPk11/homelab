#!/bin/bash
# Version: 2.3 (2026-07-10)
#
# scrape_secrets.sh — centralised secrets backup for the homelab.
#
# Architecture (keep simple, no SOPS):
#   - GitOps clone is disposable: tracked code/templates only (no real secrets).
#   - Runtime secrets live under /srv/<service>/ on each node (real files).
#   - Vault layout mirrors the search path on each host:
#       BACKUP_DIR/<host>/<absolute-path-without-leading-slash>/...
#     e.g. /srv/caddy/caddy.env  →  backups/caddy-101/srv/caddy/caddy.env
#
# Needs: rsync on every node + passwordless root SSH from this host.
# Cron:  0 2 * * 0 /opt/dev/homelab_repo/shared/scripts/scrape_secrets.sh >> /var/log/scrape_secrets.log 2>&1
#
# New node with /srv secrets: add to NODES + SRV_SWEEP_HOSTS.
# Always use root@ — bare "IP:path" follows ssh_config User and cannot read 0600 root secrets.

set -euo pipefail

BACKUP_DIR="/opt/dev/secrets_vault/backups"

declare -A NODES=(
    ["caddy-101"]="192.168.50.101"
    ["dns-102"]="192.168.50.102"
    ["homelab-95"]="192.168.50.95"
    ["omv-90"]="192.168.50.90"
    ["openclaw-91"]="192.168.50.91"
    ["proxmox-100"]="192.168.50.100"
)

# Primary: secrets beside services under /srv/<service>/
SRV_SWEEP_HOSTS=("caddy-101" "dns-102" "homelab-95")

# Transitional: secrets still overlaid on the GitOps clone (not yet moved to /srv).
# Overlaps /srv where files are symlinked into the clone — drop a host once migrated.
LEGACY_CLONE_SECRET_HOSTS=("homelab-95")

# Vault path = <host> + absolute search path (strip leading /).
vault_path() {
    local host="$1" abs_path="$2"
    abs_path="${abs_path#/}"   # /srv → srv
    echo "$BACKUP_DIR/$host/$abs_path"
}

echo "Starting secrets backup... $(date)"

echo "Purging previous backups in $BACKUP_DIR..."
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# --- /srv  →  <host>/srv/
for HOST in "${SRV_SWEEP_HOSTS[@]}"; do
    IP="${NODES[$HOST]}"
    SRC="/srv"
    DEST="$(vault_path "$HOST" "$SRC")"
    echo "Sweeping $SRC on $HOST ($IP) → $DEST"
    mkdir -p "$DEST"
    # find -xtype f skips broken symlinks; grep drops SSH banners from --files-from.
    if ! ssh -o BatchMode=yes "root@$IP" \
        "cd $SRC && find . -xtype f \( -name \"*.secret\" -o -name \"*.env\" -o -name \".env\" -o -name \".env.*\" -o -name \"*.pwd\" \)" \
        | grep '^\./' \
        | rsync -avL --files-from=- \
            "root@$IP:$SRC/" \
            "$DEST/"; then
        echo "Warning: sweep failed for $SRC on $HOST"
    fi
done

# --- /opt/homelab-repo/nodes/<host>  →  <host>/opt/homelab-repo/nodes/<host>/
for HOST in "${LEGACY_CLONE_SECRET_HOSTS[@]}"; do
    IP="${NODES[$HOST]}"
    SRC="/opt/homelab-repo/nodes/$HOST"
    DEST="$(vault_path "$HOST" "$SRC")"
    echo "Legacy clone scrape $SRC on $HOST ($IP) → $DEST"
    mkdir -p "$DEST"
    if ! rsync -avm \
        --include='*.env' --include='*.secret' --include='*.pwd' \
        --include='*/.secrets/***' --include='*/' --exclude='*' \
        "root@$IP:$SRC/" "$DEST/"; then
        echo "Warning: legacy clone scrape failed on $HOST"
    fi
done

# --- local /opt/dev/homelab_repo  →  ai-tools-105/
echo "Backing up local /opt/dev/homelab_repo..."
SRC="/opt/dev/homelab_repo"
DEST="$BACKUP_DIR/ai-tools-105"
mkdir -p "$DEST"
rsync -avm \
    --include='*.env' --include='*.secret' --include='*.pwd' \
    --include='*/.secrets/***' --include='*/' --exclude='*' \
    "$SRC/" "$DEST/" || \
    echo "Warning: local repo secret scrape failed"

# --- Host-local paths outside /srv (same rule: vault path = search path)
HOMELAB_IP="${NODES["homelab-95"]}"
OPENCLAW_IP="${NODES["openclaw-91"]}"

echo "Backing up /home/k/.openclaw on openclaw-91..."
DEST="$(vault_path "openclaw-91" "/home/k/.openclaw")"
mkdir -p "$DEST"
ssh -o BatchMode=yes "root@$OPENCLAW_IP" "cat /home/k/.openclaw/openclaw.json" \
    > "$DEST/openclaw.json" 2>/dev/null || true

echo "Backing up /home/k/.hermes on openclaw-91..."
DEST="$(vault_path "openclaw-91" "/home/k/.hermes")"
mkdir -p "$DEST"
ssh -o BatchMode=yes "root@$OPENCLAW_IP" "cat /home/k/.hermes/config.yaml" \
    > "$DEST/config.yaml" 2>/dev/null || true
ssh -o BatchMode=yes "root@$OPENCLAW_IP" "cat /home/k/.hermes/.env" \
    > "$DEST/.env" 2>/dev/null || true
ssh -o BatchMode=yes "root@$OPENCLAW_IP" "cat /home/k/.hermes/auth.json" \
    > "$DEST/auth.json" 2>/dev/null || true

# YAML under /srv (not matched by env/secret globs) — path still = /srv/...
echo "Backing up /srv/anytype/docker-generateconfig on homelab-95..."
SRC="/srv/anytype/docker-generateconfig"
DEST="$(vault_path "homelab-95" "$SRC")"
mkdir -p "$DEST"
rsync -avz --exclude='relics' \
    "root@$HOMELAB_IP:$SRC/" \
    "$DEST/" 2>/dev/null || true

# MikroTik exports live in the local repo tree — keep that path under ai-tools-105
echo "Backing up MikroTik artefacts from local repo..."
SRC="/opt/dev/homelab_repo/nodes/ai-tools-105/services/mikrotik-backup"
DEST="$BACKUP_DIR/ai-tools-105/services/mikrotik-backup"
mkdir -p "$DEST"
cp "$SRC/mikrotik-config-export.rsc" "$DEST/mikrotik-config-export.rsc" 2>/dev/null || \
    echo "Warning: MikroTik config export not found"
cp "$SRC/CHANGELOG.md" "$DEST/CHANGELOG.md" 2>/dev/null || \
    echo "Warning: MikroTik CHANGELOG.md not found"

chmod -R 600 "$BACKUP_DIR"
find "$BACKUP_DIR" -type d -exec chmod 700 {} +

echo "Secrets backup complete. Files secured in $BACKUP_DIR"
