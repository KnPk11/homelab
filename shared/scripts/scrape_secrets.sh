#!/bin/bash
# Version: 2.8 (2026-07-10)
#
# scrape_secrets.sh — centralised secrets backup for the homelab.
#
# Architecture (keep simple, no SOPS):
#   - GitOps clone is disposable: tracked code/templates only (no real secrets).
#   - Runtime secrets live under host paths like /srv/<service>/ or /opt/scripts/...
#   - Vault layout mirrors the search path on each host:
#       BACKUP_DIR/<host>/<absolute-path-without-leading-slash>/...
#     e.g. /srv/caddy/caddy.env  →  backups/caddy-101/srv/caddy/caddy.env
#
# Needs: rsync on every node + passwordless root SSH from this host.
# Cron:  0 2 * * 0 /opt/dev/homelab_repo/shared/scripts/scrape_secrets.sh >> /var/log/scrape_secrets.log 2>&1
#
# New sweep root: add "host:/abs/path" to PATH_SWEEPS.
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

# host:/absolute/path — find secret-like files under each root, vault path = same path
PATH_SWEEPS=(
    "caddy-101:/srv"
    "dns-102:/srv"
    "homelab-95:/srv"
    "homelab-95:/opt/scripts/Security"
    # Kopia client config + password (next to backup scripts)
    "homelab-95:/opt/scripts/Backups/Kopia"
)

# Vault path = <host> + absolute search path (strip leading /).
vault_path() {
    local host="$1" abs_path="$2"
    abs_path="${abs_path#/}"   # /srv → srv
    echo "$BACKUP_DIR/$host/$abs_path"
}

# Remote find + rsync of secret globs; vault dest mirrors SRC under the host.
# Only creates DEST when at least one file matches (no empty root/home/kopia dirs).
sweep_remote_path() {
    local HOST="$1" SRC="$2"
    local IP="${NODES[$HOST]}"
    local DEST list
    DEST="$(vault_path "$HOST" "$SRC")"
    echo "Sweeping $SRC on $HOST ($IP) → $DEST"

    # Capture remote file list (drop SSH banners). Empty list = nothing to do.
    list="$(
        ssh -o BatchMode=yes "root@$IP" \
            "test -d \"$SRC\" || exit 0; cd \"$SRC\" && find . -xtype f \( \
                -name \"*.secret\" -o -name \"*.env\" -o -name \".env\" -o -name \".env.*\" \
                -o -name \"*.pwd\" -o -name \"gcp-creds.json\" -o -name \"postgres_password\" \
                -o -name \"*.config\" -o -name \"*.kopia-password\" -o -name \"*kopia-password*\" \
                -o -name \"main-repo.config\" -o -name \"repository.config\" \
            \)" 2>/dev/null | grep '^\./' || true
    )"
    if [[ -z "$list" ]]; then
        echo "  (no matching files under $SRC — skipped)"
        return 0
    fi

    mkdir -p "$DEST"
    if ! printf '%s\n' "$list" | rsync -avL --files-from=- \
            "root@$IP:$SRC/" \
            "$DEST/"; then
        echo "Warning: rsync failed for $SRC on $HOST"
    else
        # Show what landed (paths only; useful for dotdirs like .config/kopia)
        echo "  files:"
        printf '%s\n' "$list" | sed 's|^\./|    |'
    fi
}

echo "Starting secrets backup... $(date)"

echo "Purging previous backups in $BACKUP_DIR..."
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

for entry in "${PATH_SWEEPS[@]}"; do
    HOST="${entry%%:*}"
    SRC="${entry#*:}"
    sweep_remote_path "$HOST" "$SRC"
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
