#!/bin/bash
# Version: 2.11 (2026-07-16)
#
# scrape_secrets.sh — centralised secrets backup for the homelab.
#
# Architecture (keep simple, no SOPS):
#   - GitOps clone is disposable: tracked code/templates only (no real secrets).
#   - Runtime secrets live under host paths like /srv/<service>/ or /opt/scripts/...
#   - Vault layout mirrors the search path on each host:
#       BACKUP_DIR/<host>/<absolute-path-without-leading-slash>/...
#     e.g. /srv/caddy/caddy.env  →  backups/reverse-proxy/srv/caddy/caddy.env
#
# Needs: rsync on every node + root SSH from this host.
# God Mode: many hosts authorize root only via ~/.ssh/id_ed25519_ai (passphrase).
#   Unlock first:  ai-key-unlock
#   Then ensure this shell sees the agent (script auto-sources ~/.ssh/ai-key-agent.sh).
# Usage: Run ON DEMAND ONLY. Do not use crontab. Move the secrets_vault to a safe offline location immediately after.
#
# New sweep root: add "host:/abs/path" to PATH_SWEEPS.
# Always use root@ — bare "IP:path" follows ssh_config User and cannot read 0600 root secrets.

set -euo pipefail

# Shared agent env from ai-key-unlock (must not be *.env — sandbox/deny lists)
if [[ -f "${HOME}/.ssh/ai-key-agent.sh" ]]; then
  # shellcheck disable=SC1091
  source "${HOME}/.ssh/ai-key-agent.sh"
fi

BACKUP_DIR="/opt/dev/secrets_vault/backups"

# SSH for root scrapes — prefer God Mode key when present (matches shared/ssh/config)
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o IdentitiesOnly=yes)
if [[ -f "${HOME}/.ssh/id_ed25519_ai" ]]; then
  SSH_OPTS+=(-i "${HOME}/.ssh/id_ed25519_ai")
fi
# Single string for rsync -e
RSYNC_RSH="ssh ${SSH_OPTS[*]}"

ssh_root() {
  local ip="$1"
  shift
  ssh "${SSH_OPTS[@]}" "root@${ip}" "$@"
}

# Fail clearly if we cannot log in as root (do not pretend /srv is empty).
require_root_ssh() {
  local host="$1" ip="$2"
  local err
  if ! err="$(ssh_root "$ip" "true" 2>&1)"; then
    echo "ERROR: cannot SSH as root@${ip} (${host})." >&2
    echo "  Unlock God Mode first:  ai-key-unlock" >&2
    echo "  Then re-run in the same environment (SSH_AUTH_SOCK must be set)." >&2
    echo "  Detail: ${err}" >&2
    return 1
  fi
}

declare -A NODES=(
    ["proxmox-host"]="192.168.50.100"
    ["pulse"]="192.168.50.88"
    ["reverse-proxy"]="192.168.50.101"
    ["dns"]="192.168.50.102"
    ["docker-services"]="192.168.50.95"
    ["nas"]="192.168.50.90"
    ["lab-vm"]="192.168.50.91"
)
PATH_SWEEPS=(
    "reverse-proxy:/srv"
    "dns:/srv"
    "docker-services:/srv"
    "docker-services:/opt/scripts/Security"
    # Kopia client config + password (next to backup scripts)
    "docker-services:/opt/scripts/Backups/Kopia"
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

    # Prove SSH works before treating empty find as "no secrets"
    if ! require_root_ssh "$HOST" "$IP"; then
        return 1
    fi

    # Capture remote file list (drop SSH banners). Empty list = nothing to do.
    list="$(
        ssh_root "$IP" \
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
    if ! printf '%s\n' "$list" | rsync -avL -e "$RSYNC_RSH" --files-from=- \
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
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    echo "SSH agent: $SSH_AUTH_SOCK"
else
    echo "WARNING: SSH_AUTH_SOCK unset — passphrase-protected keys will fail (run ai-key-unlock)."
fi

echo "Purging previous backups in $BACKUP_DIR..."
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

for entry in "${PATH_SWEEPS[@]}"; do
    HOST="${entry%%:*}"
    SRC="${entry#*:}"
    sweep_remote_path "$HOST" "$SRC" || true
done

# --- local /opt/dev/homelab_repo  →  ai-tools/
echo "Backing up local /opt/dev/homelab_repo..."
SRC="/opt/dev/homelab_repo"
DEST="$BACKUP_DIR/ai-tools"
mkdir -p "$DEST"
rsync -avm \
    --include='*.env' --include='*.secret' --include='*.pwd' \
    --include='*/.secrets/***' --include='*/' --exclude='*' \
    "$SRC/" "$DEST/" || \
    echo "Warning: local repo secret scrape failed"

# --- Host-local paths outside /srv (same rule: vault path = search path)
HOMELAB_IP="${NODES["docker-services"]}"
OPENCLAW_IP="${NODES["lab-vm"]}"

echo "Backing up /home/k/.openclaw on lab-vm..."
DEST="$(vault_path "lab-vm" "/home/k/.openclaw")"
mkdir -p "$DEST"
ssh_root "$OPENCLAW_IP" "cat /home/k/.openclaw/openclaw.json" \
    > "$DEST/openclaw.json" 2>/dev/null || true

echo "Backing up /home/k/.hermes on lab-vm..."
DEST="$(vault_path "lab-vm" "/home/k/.hermes")"
mkdir -p "$DEST"
ssh_root "$OPENCLAW_IP" "cat /home/k/.hermes/config.yaml" \
    > "$DEST/config.yaml" 2>/dev/null || true
ssh_root "$OPENCLAW_IP" "cat /home/k/.hermes/.env" \
    > "$DEST/.env" 2>/dev/null || true
ssh_root "$OPENCLAW_IP" "cat /home/k/.hermes/auth.json" \
    > "$DEST/auth.json" 2>/dev/null || true

# AnyType self-host (docker-services) — YAML/identity not matched by env/secret globs.
# PATH_SWEEPS already gets /srv/anytype-sync-logic/.env (+ .env.override if present).
# Full trees (vault path = host path):
#   /srv/anytype/docker-generateconfig/  → .networkId, signing key, account*.yml, nodes.yml
#   /srv/anytype-sync-logic/etc/         → client.yml (apps), node configs, .aws/
# client.yml lives at etc/client.yml (not under docker-generateconfig).
if require_root_ssh "docker-services" "$HOMELAB_IP"; then
    for SRC in \
        /srv/anytype/docker-generateconfig \
        /srv/anytype-sync-logic/etc
    do
        echo "Backing up $SRC on docker-services..."
        DEST="$(vault_path "docker-services" "$SRC")"
        if ssh_root "$HOMELAB_IP" "test -d \"$SRC\""; then
            mkdir -p "$DEST"
            if rsync -avz -e "$RSYNC_RSH" \
                    "root@$HOMELAB_IP:$SRC/" \
                    "$DEST/"; then
                # Surface important files in scrape output (rsync -v is noisy; list key paths)
                if [[ "$SRC" == */etc ]]; then
                    if [[ -f "$DEST/client.yml" ]]; then
                        echo "  OK: client.yml → $DEST/client.yml ($(wc -c <"$DEST/client.yml") bytes)"
                    else
                        echo "  WARNING: client.yml missing under $DEST after rsync"
                    fi
                fi
                if [[ "$SRC" == */docker-generateconfig ]]; then
                    if [[ -f "$DEST/.networkId" ]]; then
                        echo "  OK: .networkId → $(tr -d '\n' <"$DEST/.networkId")"
                    else
                        echo "  WARNING: .networkId missing under $DEST after rsync"
                    fi
                fi
            else
                echo "Warning: rsync failed for $SRC on docker-services"
            fi
        else
            echo "  (missing $SRC — skipped)"
        fi
    done
else
    echo "Warning: skipped AnyType trees (root SSH to docker-services failed)"
fi

# Pulse (pulse) — Explicit bare-minimum secrets, keys, and configs
if require_root_ssh "pulse" "${NODES["pulse"]}"; then
    echo "Backing up /etc/pulse on pulse..."
    DEST="$(vault_path "pulse" "/etc/pulse")"
    mkdir -p "$DEST"
    rsync -avz -e "$RSYNC_RSH" \
        --include='/.env' \
        --include='/.encryption.key' \
        --include='/.install_id' \
        --include='/nodes.enc' \
        --include='/system.json' \
        --include='/org.json' \
        --include='/api_tokens.json' \
        --exclude='*' \
        "root@${NODES["pulse"]}:/etc/pulse/" "$DEST/" || \
        echo "Warning: rsync failed for /etc/pulse on pulse"
else
    echo "Warning: skipped Pulse tree (root SSH to pulse failed)"
fi



chmod -R 600 "$BACKUP_DIR"
find "$BACKUP_DIR" -type d -exec chmod 700 {} +

echo "Secrets backup complete. Files secured in $BACKUP_DIR"
