#!/bin/bash
#
# Kopia backup script - Single Repository, Modular
#
# This script MUST be run with sudo or as root.
# Prune unused volumes and use the docker shutdown script before backing up docker directory
#
# Usage:
#   sudo ./homelab_backup_kopia.sh [data|srv|docker|maintenance]


set -euo pipefail

# --- Globals ---
REPO_DIR="/mnt/nas/Apps/Kopia/homelab-backup"
KOPIA_CONFIG_FILE="/opt/scripts/Backups/Kopia/config/main-repo.config"
LOGFILE="/opt/scripts/Backups/Kopia/logs/backup.log"
IGNORE_FILE="/opt/scripts/Backups/Kopia/global.kopiaignore"
REPO_OWNER="1000"
REPO_GROUP="1000"

# # --- SECRETS ---
# Source the repository password securely
# source "/data/secrets/kopia.env" # Automatically fetched from Kopia/config/main-repo.config.kopia-password
# source "/data/secrets/storj.env"
# BASE_REPO="s3:https://gateway.storjshare.io/homelab-backup"

# --- Source Paths ---
SRV_PATH="/srv"
DATA_PATH="/data"
DOCKER_VOLS_PATH="/var/lib/docker/volumes"

# --- Retention Policies (Kopia Format) ---
COMPRESSION_ALGO="zstd"
RETENTION_SRV="--keep-latest 25 --compression $COMPRESSION_ALGO"
RETENTION_DATA="--keep-latest 25 --compression $COMPRESSION_ALGO"
RETENTION_DOCKER="--keep-latest 25 --compression $COMPRESSION_ALGO"



timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOGFILE"; }

# --- Check if running as root ---
if [[ "$EUID" -ne 0 ]]; then
  log "❌ ERROR: This script must be run as root (use sudo)."
  exit 1
fi

# ===============================================
# === INDIVIDUAL FUNCTIONS ======================
# ===============================================

# --- Back up /data (SAFE to run anytime) ---
function backup_data() {
    log "🔗 Updating exclusion symlink..."
    # This creates the .kopiaignore file inside /srv pointing to your master list
    ln -sf "/opt/scripts/Backups/Kopia/global.ignore" "$DATA_PATH/.kopiaignore"

    log "📦 Backing up $DATA_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DATA_PATH" \
        --tags "type:data" \
        | tee -a "$LOGFILE"
    log "=== Finished 'data' Backup ==="
}

# --- Back up /srv (STOPS Docker) ---
function backup_srv() {
    log "🔗 Updating exclusion symlink..."
    # This creates the .kopiaignore file inside /srv pointing to your master list
    ln -sf "/opt/scripts/Backups/Kopia/global.ignore" "$SRV_PATH/.kopiaignore"

    log "📦 Backing up $SRV_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$SRV_PATH" \
        --tags "type:srv" \
        | tee -a "$LOGFILE"

    log "=== Finished 'srv' Backup ==="
}

# --- Back up Docker Volumes (STOPS Docker) ---
function backup_docker() {
    log "🔗 Updating exclusion symlink..."
    ln -sf "/opt/scripts/Backups/Kopia/global.ignore" "$DOCKER_VOLS_PATH/.kopiaignore"

    log "📦 Backing up $DOCKER_VOLS_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DOCKER_VOLS_PATH" \
        --tags "type:docker" \
        | tee -a "$LOGFILE"

    log "=== Finished 'docker' Backup ==="
}


# --- Run Maintenance (Applies Compression, Retention & Reclaims Space) ---
function run_maintenance() {
    log "=== Starting Repository Maintenance ==="

    # 1. Update/Sync Policies (Ensuring retention and ignores are active)
    log "🧹 Syncing policies for srv, data, and docker..."
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$SRV_PATH" $RETENTION_SRV > /dev/null
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$DATA_PATH" $RETENTION_DATA > /dev/null
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$DOCKER_VOLS_PATH" $RETENTION_DOCKER > /dev/null

    # 2. Expire Snapshots (Marks data for deletion based on retention rules)
    log "🧹 Expiring old snapshots..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot expire --all --delete | tee -a "$LOGFILE"

    # 3. Full Maintenance (Physically deletes orphaned data from disk)
    # Note: This is the command that actually reduces the size of your backup folder. Add --safety=none to override the 24h retention
    log "🚀 Running FULL maintenance to reclaim disk space..."
    kopia --config-file "$KOPIA_CONFIG_FILE" maintenance run --full --safety=none | tee -a "$LOGFILE"

    # 4. Integrity Check
    log "🔍 Running repository integrity check..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot verify | tee -a "$LOGFILE"

    log "=== Finished Repository Maintenance ==="
}


# --- Set Final Ownership ---
function set_ownership() {
    log "🙍 Applying final ownership of repository to user '$REPO_OWNER'..."
    
    # Change ownership of the repo directory
    chown -R "$REPO_OWNER:$REPO_GROUP" "$REPO_DIR"
    log "✅ Ownership set to $REPO_OWNER."
}

# ===============================================
# === SCRIPT ROUTER =============================
# ===============================================

# Use $1 as the command, default to 'all' if not provided
COMMAND="${1:-all}"

log "Script invoked with command: '$COMMAND'"

case "$COMMAND" in
    data)
        backup_data
        ;;
    srv)
        backup_srv
        ;;
    docker)
        backup_docker
        ;;
    maintenance)
        run_maintenance
        ;;
    *)
        echo "❌ ERROR: Unknown command '$COMMAND'"
        echo "Usage: $0 [data|srv|docker|maintenance]"
        exit 1
        ;;
esac

# === FINAL STEPS ===
# Runs after any command

log "Running final ownership check..."
set_ownership

log "Script finished command: '$COMMAND'"
log "Consider running maintenance mode if you're finished"