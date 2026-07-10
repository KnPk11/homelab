#!/bin/bash
#
# ==============================================================================
# Kopia Backup Script - Homelab Unified
# ==============================================================================
# Description: Snapshots /srv, /data, and Docker volumes; policies + maintenance.
# Version:     3.1 (2026-07-10)
# Usage:       sudo kopia-backup [data|srv|docker|maintenance]
#              sudo /opt/scripts/Backups/Kopia/homelab_backup_kopia.sh ...
#
# Secrets (host-only, not in Git):
#   /opt/scripts/Backups/Kopia/config/main-repo.config
#   /opt/scripts/Backups/Kopia/config/main-repo.config.kopia-password
# ==============================================================================

set -euo pipefail
umask 0002

# --- Host runtime paths (tracked scripts are symlinked here from GitOps) ---
RUNTIME_DIR="/opt/scripts/Backups/Kopia"
REPO_DIR="/mnt/nas/Apps/Kopia/homelab-backup"
KOPIA_CONFIG_FILE="$RUNTIME_DIR/config/main-repo.config"
LOGFILE="$RUNTIME_DIR/logs/backup.log"
IGNORE_FILE="$RUNTIME_DIR/global.kopiaignore"
REPO_OWNER="1000"
REPO_GROUP="1000"

# --- Snapshot roots ---
SRV_PATH="/srv"
DATA_PATH="/data"
DOCKER_VOLS_PATH="/var/lib/docker/volumes"

# --- Retention ---
COMPRESSION_ALGO="zstd"
RETENTION_SRV="--keep-latest 25 --compression $COMPRESSION_ALGO"
RETENTION_DATA="--keep-latest 25 --compression $COMPRESSION_ALGO"
RETENTION_DOCKER="--keep-latest 25 --compression $COMPRESSION_ALGO"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOGFILE"; }

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: This script must be run as root (use sudo)."
  exit 1
fi

if [[ ! -f "$KOPIA_CONFIG_FILE" ]]; then
  log "ERROR: missing $KOPIA_CONFIG_FILE"
  log "Restore config + .kopia-password from secrets vault, or run initialise_repository.sh once."
  exit 1
fi

mkdir -p "$(dirname "$LOGFILE")"

function backup_data() {
    log "Updating exclusion symlink..."
    ln -sfn "$IGNORE_FILE" "$DATA_PATH/.kopiaignore"
    log "Backing up $DATA_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DATA_PATH" --tags "type:data" | tee -a "$LOGFILE"
    log "=== Finished 'data' Backup ==="
}

function backup_srv() {
    log "Updating exclusion symlink..."
    ln -sfn "$IGNORE_FILE" "$SRV_PATH/.kopiaignore"
    log "Backing up $SRV_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$SRV_PATH" --tags "type:srv" | tee -a "$LOGFILE"
    log "=== Finished 'srv' Backup ==="
}

function backup_docker() {
    log "Updating exclusion symlink..."
    ln -sfn "$IGNORE_FILE" "$DOCKER_VOLS_PATH/.kopiaignore"
    log "Backing up $DOCKER_VOLS_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DOCKER_VOLS_PATH" --tags "type:docker" | tee -a "$LOGFILE"
    log "=== Finished 'docker' Backup ==="
}

function run_maintenance() {
    log "=== Starting Repository Maintenance ==="
    log "Syncing policies..."
    # shellcheck disable=SC2086
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$SRV_PATH" $RETENTION_SRV > /dev/null
    # shellcheck disable=SC2086
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$DATA_PATH" $RETENTION_DATA > /dev/null
    # shellcheck disable=SC2086
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$DOCKER_VOLS_PATH" $RETENTION_DOCKER > /dev/null
    log "Expiring old snapshots..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot expire --all --delete | tee -a "$LOGFILE"
    log "Running FULL maintenance..."
    kopia --config-file "$KOPIA_CONFIG_FILE" maintenance run --full --safety=none | tee -a "$LOGFILE"
    log "Running integrity check..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot verify | tee -a "$LOGFILE"
    log "=== Finished Repository Maintenance ==="
}

function set_ownership() {
    log "Applying final ownership to user '$REPO_OWNER'..."
    chown -R "$REPO_OWNER:$REPO_GROUP" "$REPO_DIR"
    log "Ownership set."
}

COMMAND="${1:-}"
if [[ -z "$COMMAND" ]]; then
  echo "Usage: $0 [data|srv|docker|maintenance]"
  exit 1
fi

log "Script invoked with command: '$COMMAND'"

case "$COMMAND" in
    data) backup_data ;;
    srv) backup_srv ;;
    docker) backup_docker ;;
    maintenance) run_maintenance ;;
    *)
        echo "ERROR: Unknown command '$COMMAND'"
        echo "Usage: $0 [data|srv|docker|maintenance]"
        exit 1
        ;;
esac

# set_ownership  # optional: uncomment if NAS perms need enforcing after each run
log "Script finished command: '$COMMAND'"
