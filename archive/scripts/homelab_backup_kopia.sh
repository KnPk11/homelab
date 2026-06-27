#!/bin/bash
#
# Kopia backup script - Single Repository, Modular
#
# Usage: sudo ./this_script.sh [all|data|srv|docker|maintenance]

set -euo pipefail

# --- Globals ---
# UPDATE: Moved config to a safer standard location
KOPIA_CONFIG_FILE="/etc/kopia/repository.config"
LOGFILE="/mnt/nas/Apps/Kopia/homelab-backup/backup.log"

# --- Source Paths ---
SRV_PATH="/srv"
DATA_PATH="/data"
DOCKER_VOLS_PATH="/var/lib/docker/volumes"

# --- Retention & Compression Policies ---
# We add compression here so we can apply it during maintenance
COMPRESSION_ALGO="zstd"
RETENTION_ARGS="--keep-latest 10 --compression $COMPRESSION_ALGO"

# --- Global array for Docker paths ---
declare -a docker_paths

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
    log "=== Starting 'data' Backup (Docker NOT stopped) ==="
    log "📦 Backing up $DATA_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DATA_PATH" \
        --tags "type:data" \
        | tee -a "$LOGFILE"
    log "=== Finished 'data' Backup ==="
}

# --- Back up /srv (STOPS Docker) ---
function backup_srv() {
    log "=== Starting 'srv' Backup (Stopping Docker) ==="
    log "⏹️ Stopping Docker to safely read volumes..."
    systemctl stop docker

    log "📦 Backing up $SRV_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$SRV_PATH" \
        --tags "type:srv" \
        | tee -a "$LOGFILE"

    log "▶️ Starting Docker..."
    systemctl start docker
    log "=== Finished 'srv' Backup ==="
}

# --- Back up Docker Volumes (STOPS Docker) ---
function backup_docker() {
    log "=== Starting 'docker' Backup (Stopping Docker) ==="
    log "⏹️ Stopping Docker to safely read volumes..."
    systemctl stop docker

    log "📦 Backing up $DOCKER_VOLS_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DOCKER_VOLS_PATH" \
        --tags "type:docker-volume" \
        | tee -a "$LOGFILE"

    log "▶️ Starting Docker..."
    systemctl start docker
    log "=== Finished 'docker' Backup ==="
}

# --- Run Maintenance (Applies Compression & Retention) ---
function run_maintenance() {
    log "=== Starting Repository Maintenance ==="
    log "🧹 Applying retention policies and compression ($COMPRESSION_ALGO)..."
    
    # Set policy for SRV
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$SRV_PATH" $RETENTION_ARGS \
        | tee -a "$LOGFILE"

    # Set policy for DATA
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$DATA_PATH" $RETENTION_ARGS \
        | tee -a "$LOGFILE"

    # Set policy for DOCKER
    kopia --config-file "$KOPIA_CONFIG_FILE" policy set "$DOCKER_VOLS_PATH" $RETENTION_ARGS \
        | tee -a "$LOGFILE"

    log "🧹 Pruning old snapshots..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot expire "$SRV_PATH" --delete | tee -a "$LOGFILE"
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot expire "$DATA_PATH" --delete | tee -a "$LOGFILE"
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot expire "$DOCKER_VOLS_PATH" --delete | tee -a "$LOGFILE"

    log "Running repository integrity check..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot verify | tee -a "$LOGFILE"
    log "=== Finished Repository Maintenance ==="
}

# --- Set Final Ownership ---
function set_ownership() {
    local original_user="${SUDO_USER:-}"
    if [ -n "$original_user" ] && [ "$original_user" != "root" ]; then
        log "🙍 Applying final ownership of repository to user '$original_user'..."
        # Only change ownership of the log directory, not the repo itself if it's external
        chown -R "$original_user:$original_user" "$(dirname "$LOGFILE")"
        log "✅ Ownership set."
    else
        log "Script run by root or SUDO_USER not set, skipping ownership change."
    fi
}

# --- Full, Optimized Backup ---
function run_all_backups() {
    log "================================="
    log "Starting Full Homelab Kopia Backup"
    log "================================="

    # NOTE: You were calling 'get_docker_paths' here but the function 
    # was missing from your upload. I have commented it out to prevent errors.
    # get_docker_paths

    # === STEP 2: Stop Docker & Run Critical Backups ===
    log "⏹️ Stopping Docker to safely read volumes..."
    systemctl stop docker

    log "📦 Backing up $SRV_PATH..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$SRV_PATH" \
        --tags "type:srv" \
        | tee -a "$LOGFILE"
    
    # Consolidated Docker Volume Backup
    log "📦 Backing up Docker Volumes ($DOCKER_VOLS_PATH)..."
    kopia --config-file "$KOPIA_CONFIG_FILE" snapshot create "$DOCKER_VOLS_PATH" \
        --tags "type:docker-volume" \
        | tee -a "$LOGFILE"

    # === STEP 3: Restart Docker (ASAP) ===
    log "▶️ Starting Docker..."
    systemctl start docker

    # === STEP 4: Run Non-Critical Backups ===
    backup_data 

    # === STEP 5: Maintenance ===
    run_maintenance

    # === STEP 6: Final Cleanup ===
    set_ownership

    log "================================="
    log "Homelab Kopia Backup Finished"
    log "================================="
}

# ===============================================
# === SCRIPT ROUTER =============================
# ===============================================

COMMAND="${1:-all}"

log "Script invoked with command: '$COMMAND'"

case "$COMMAND" in
    all)
        run_all_backups
        ;;
    data)
        backup_data
        run_maintenance 
        ;;
    srv)
        backup_srv
        run_maintenance
        ;;
    docker)
        backup_docker
        run_maintenance
        ;;
    maintenance)
        run_maintenance
        ;;
    *)
        echo "❌ ERROR: Unknown command '$COMMAND'"
        echo "Usage: $0 [all|data|srv|docker|maintenance]"
        exit 1
        ;;
esac

log "Running final ownership check..."
set_ownership

log "Script finished command: '$COMMAND'"