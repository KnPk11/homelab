#!/bin/bash
#
# ==============================================================================
# Kopia Backup Script - Homelab Unified
# ==============================================================================
# Description: Modular backup logic for /srv, /data, and Docker Volumes.
#              Automates snapshot creation, policy enforcement, and maintenance.
# Version:     3.0 (2026-05-22)
# Repository:  Managed on ai-tools management node.
# Usage:       sudo ./backup.sh [data|srv|docker|maintenance]
# ==============================================================================

set -euo pipefail

# --- Globals ---
REPO_DIR="/mnt/nas/Apps/Kopia/homelab-backup"
KOPIA_CONFIG_FILE="/opt/scripts/Backups/Kopia/config/main-repo.config"
LOGFILE="/opt/scripts/Backups/Kopia/logs/backup.log"
IGNORE_FILE="/opt/scripts/Backups/Kopia/global.kopiaignore"
REPO_OWNER="1000"
REPO_GROUP="1000"

# --- Source Paths ---
SRV_PATH="/srv"
DATA_PATH="/data"
DOCKER_VOLS_PATH="/var/lib/docker/volumes"

# --- Retention Policies ---
COMPRESSION_ALGO="zstd"
RETENTION_SRV="--keep-latest 25 --compression $COMPRESSION_ALGO"
RETENTION_DATA="--keep-latest 25 --compression $COMPRESSION_ALGO"
RETENTION_DOCKER="--keep-latest 25 --compression $COMPRESSION_ALGO"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOGFILE"; }

if [[ "$EUID" -ne 0 ]]; then
  log "❌ ERROR: This script must be run as root (use sudo)."
  exit 1
fi

function backup_data() {
    log "🔗 Updating exclusion symlink..."
    ln -sf "/opt/scripts/Backups/Kopia/global.ignore" "$DATA_PATH/.kopiaignore"
    log "📦 Backing up $DATA_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DATA_PATH" --tags "type:data" | tee -a "$LOGFILE"
    log "=== Finished 'data' Backup ==="
}

function backup_srv() {
    log "🔗 Updating exclusion symlink..."
    ln -sf "/opt/scripts/Backups/Kopia/global.ignore" "$SRV_PATH/.kopiaignore"
    log "📦 Backing up $SRV_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$SRV_PATH" --tags "type:srv" | tee -a "$LOGFILE"
    log "=== Finished 'srv' Backup ==="
}

function backup_docker() {
    log "🔗 Updating exclusion symlink..."
    ln -sf "/opt/scripts/Backups/Kopia/global.ignore" "$DOCKER_VOLS_PATH/.kopiaignore"
    log "📦 Backing up $DOCKER_VOLS_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DOCKER_VOLS_PATH" --tags "type:docker" | tee -a "$LOGFILE"
    log "=== Finished 'docker' Backup ==="
}

function run_maintenance() {
    log "=== Starting Repository Maintenance ==="
    log "🧹 Syncing policies..."
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$SRV_PATH" $RETENTION_SRV > /dev/null
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$DATA_PATH" $RETENTION_DATA > /dev/null
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$DOCKER_VOLS_PATH" $RETENTION_DOCKER > /dev/null
    log "🧹 Expiring old snapshots..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot expire --all --delete | tee -a "$LOGFILE"
    log "🚀 Running FULL maintenance..."
    kopia --config-file "$KOPIA_CONFIG_FILE" maintenance run --full --safety=none | tee -a "$LOGFILE"
    log "🔍 Running integrity check..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot verify | tee -a "$LOGFILE"
    log "=== Finished Repository Maintenance ==="
}

function set_ownership() {
    log "🙍 Applying final ownership to user '$REPO_OWNER'..."
    chown -R "$REPO_OWNER:$REPO_GROUP" "$REPO_DIR"
    log "✅ Ownership set."
}

COMMAND="${1:-all}"
log "Script invoked with command: '$COMMAND'"

case "$COMMAND" in
    data) backup_data ;;
    srv) backup_srv ;;
    docker) backup_docker ;;
    maintenance) run_maintenance ;;
    *)
        echo "❌ ERROR: Unknown command '$COMMAND'"
        echo "Usage: $0 [data|srv|docker|maintenance]"
        exit 1
        ;;
esac

log "Running final ownership check..."
set_ownership
log "Script finished command: '$COMMAND'"
