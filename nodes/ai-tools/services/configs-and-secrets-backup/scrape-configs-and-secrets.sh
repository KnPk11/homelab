#!/bin/bash
# =============================================================================
# scrape-configs-and-secrets.sh
# Version: 2.15
# Date: 2026-10-31
#
# Centralised live-node configs & secrets backup into secrets_vault (rsync, no SOPS).
# Requires God Mode SSH (ai-key-unlock). ON DEMAND ONLY — not for cron.
# Move vault offline after the run.
#
# Usage:
#   ai-key-unlock && ./scrape-configs-and-secrets.sh
# =============================================================================
set -euo pipefail

# Shared agent env from ai-key-unlock (must not be *.env — sandbox/deny lists)
if [[ -f "${HOME}/.ssh/ai-key-agent.sh" ]]; then
  # shellcheck disable=SC1091
  source "${HOME}/.ssh/ai-key-agent.sh"
fi

BACKUP_DIR="/opt/dev/secrets_vault/configs_and_secrets"

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
    ["k8s"]="192.168.50.96"
    ["scratch-pc"]="192.168.50.85"
    ["ops"]="192.168.50.112"
)
PATH_SWEEPS=(
    "reverse-proxy:/srv"
    "dns:/srv"
    "ops:/srv"
    "k8s:/srv"
    "lab-vm:/srv"
    "scratch-pc:/srv"
    "docker-services:/srv"
    "docker-services:/opt/scripts/Security"
    # Public web-apps clone (story-cards/.env; other apps may add .env later)
    "lab-vm:/opt/web-apps"
    "scratch-pc:/opt/web-apps"
    "nas:/opt/scripts/Security"
    "proxmox-host:/opt/scripts/Security"
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
                -o -name \"*.rsc\" \
            \) ! -name '*sops*'" 2>/dev/null | grep '^\./' || true
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

echo "Starting configs & secrets backup... $(date)"
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    echo "SSH agent: $SSH_AUTH_SOCK"
else
    echo "WARNING: SSH_AUTH_SOCK unset — passphrase-protected keys will fail (run ai-key-unlock)."
fi

# Verify God Mode SSH works BEFORE purging the existing backup directory.
if ! require_root_ssh "proxmox-host" "${NODES["proxmox-host"]}"; then
    echo "Aborting before purging $BACKUP_DIR." >&2
    exit 1
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

# --- Host-local paths outside /srv (same rule: vault path = search path)
HOMELAB_IP="${NODES["docker-services"]}"
OPENCLAW_IP="${NODES["lab-vm"]}"

pull_remote_file() {
    local ip="$1" remote_file="$2" local_dest="$3"
    local tmp
    tmp="$(mktemp)"
    if ssh_root "$ip" "test -f \"$remote_file\" && cat \"$remote_file\"" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        mkdir -p "$(dirname "$local_dest")"
        mv "$tmp" "$local_dest"
    else
        rm -f "$tmp"
    fi
}

if require_root_ssh "lab-vm" "$OPENCLAW_IP"; then
    echo "Backing up /home/k/.openclaw on lab-vm..."
    DEST="$(vault_path "lab-vm" "/home/k/.openclaw")"
    pull_remote_file "$OPENCLAW_IP" "/home/k/.openclaw/openclaw.json" "$DEST/openclaw.json"

    echo "Backing up /home/k/.hermes on lab-vm..."
    DEST="$(vault_path "lab-vm" "/home/k/.hermes")"
    pull_remote_file "$OPENCLAW_IP" "/home/k/.hermes/config.yaml" "$DEST/config.yaml"
    pull_remote_file "$OPENCLAW_IP" "/home/k/.hermes/.env" "$DEST/.env"
    pull_remote_file "$OPENCLAW_IP" "/home/k/.hermes/auth.json" "$DEST/auth.json"

    echo "Backing up /opt/paperclip on lab-vm..."
    DEST="$(vault_path "lab-vm" "/opt/paperclip/data/instances/default")"
    pull_remote_file "$OPENCLAW_IP" "/opt/paperclip/data/instances/default/.env" "$DEST/.env"
    pull_remote_file "$OPENCLAW_IP" "/opt/paperclip/data/instances/default/config.json" "$DEST/config.json"
    pull_remote_file "$OPENCLAW_IP" "/opt/paperclip/data/instances/default/secrets/master.key" "$DEST/secrets/master.key"
    pull_remote_file "$OPENCLAW_IP" "/opt/paperclip/data/instances/default/secrets/decision-signing.key" "$DEST/secrets/decision-signing.key"
else
    echo "Warning: skipped lab-vm explicit files (root SSH to lab-vm failed)"
fi

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

echo "Configs & secrets backup complete. Files secured in $BACKUP_DIR"
