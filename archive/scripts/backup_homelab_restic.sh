#!/bin/bash

# Set the correct RESTIC_BASE_REPO
# Run as sudo

set -euo pipefail


export RESTIC_PASSWORD_FILE="/data/secrets/restic_backup"

# Load the Storj S3 credentials into the environment
source "/data/secrets/storj.env"


# Globals for docker backup
RESTIC_BASE_REPO="/mnt/nas/homelab-backup"
# RESTIC_BASE_REPO="s3:https://gateway.storjshare.io/homelab-backup"


timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOGFILE"; }


backup_repo() {
    local REPO="$1"
    local SOURCE="$2"
    local TAG="$3"
    local TMP_RESTORE="$4"
    local RETENTION="$5"
    local LOGFILE="$6"

    log "=== Starting backup of $SOURCE to $REPO ==="

    # --- Special handling for /srv directory ---
    local containers_to_stop=()
    if [[ "$SOURCE" == "/srv" ]]; then
        log "⏹️ Stopping Docker to safely read volumes..."
        sudo systemctl stop docker
    fi
    # --- End of special handling ---

    # Clear stale locks
    restic -r "$REPO" unlock | tee -a "$LOGFILE"

    # 1️⃣ Backup
    (cd "$SOURCE" && restic -r "$REPO" backup . --tag "$TAG" \
    --exclude="data/certs/old" \
    --exclude="data/compose/dir" \
    | tee -a "$LOGFILE")

    # # --- Restart docker for /srv ---
    # if [[ "$SOURCE" == "/srv" ]]; then
    #     log "▶️ Starting Docker..."
    #     sudo systemctl start docker
    # fi
    # # --- End of restart logic ---

    # 2️⃣ Integrity check
    log "Running repository integrity check..."
    restic -r "$REPO" check | tee -a "$LOGFILE"

    # 3️⃣ Prune old snapshots with repo-specific rules
    log "Pruning old snapshots with policy: $RETENTION"
    restic -r "$REPO" forget $RETENTION --prune | tee -a "$LOGFILE"

    # # 4️⃣ Test restore
    # log "Restoring latest snapshot to $TMP_RESTORE..."
    # rm -rf "$TMP_RESTORE"
    # mkdir -p "$TMP_RESTORE"
    # restic -r "$REPO" restore latest --target "$TMP_RESTORE" | tee -a "$LOGFILE"
    
    # # Optional: Verify the restore isn't empty
    # if [ -z "$(ls -A "$TMP_RESTORE")" ]; then
    #     log "❌ WARNING: Restore test for $SOURCE resulted in an empty directory!"
    # else
    #     log "✅ Restore test for $SOURCE successful."
    # fi

    log "=== Finished backup of $SOURCE ==="
}

backup_docker() {
    local REPO="$1"
    local SOURCE="$2"
    local TAG="$3"
    local TMP_RESTORE="$4"
    local RETENTION="$5"
    local LOGFILE="$6"

    # === STEP 1: Get list of volumes WHILE DOCKER IS RUNNING ===
    log "🧹 Removing unused Docker volumes..."
    docker volume prune -f

    log "🔍 Collecting Docker volume information..."
    mapfile -t volumes < <(docker volume ls --format '{{.Name}}')

    if [ ${#volumes[@]} -eq 0 ]; then
        log "⚠️ No Docker volumes found to back up. Exiting function."
        return
    fi

    # Build a list of relative paths to back up
    paths=()
    for volume in "${volumes[@]}"; do
        local rel_path="$volume/_data"
        if [ -d "$SOURCE/$rel_path" ]; then
            paths+=("$rel_path")
        fi
    done
    
    if [ ${#paths[@]} -eq 0 ]; then
        log "⚠️ Volume names were found, but none had a '_data' directory. Nothing to back up."
        return
    fi

    # === STEP 2: Stop Docker to ensure data consistency ===
    log "⏹️ Stopping Docker to safely read volumes..."
    sudo systemctl stop docker

    # === STEP 3: Run the backup AS ROOT ===
    # Clear stale locks
    restic -r "$REPO" unlock | tee -a "$LOGFILE"

    log "📦 Backing up all volumes in one Restic run..."
    # Use 'sudo -E' to run restic as root AND preserve the RESTIC_PASSWORD_FILE environment variable.
    (cd "$SOURCE" && sudo -E restic -r "$REPO" backup "${paths[@]}" --tag "$TAG" | tee -a "$LOGFILE")

    # === STEP 4: Start Docker again AS SOON AS POSSIBLE ===
    log "▶️ Starting Docker..."
    sudo systemctl start docker

    # === STEP 5: Maintenance and Testing (can be done with Docker running) ===
    log "🧹 Applying retention policy..."
    # No sudo needed here unless the repo itself is owned by root
    restic -r "$REPO" forget $RETENTION --prune | tee -a "$LOGFILE"

    # log "🧪 Restoring latest snapshot to $TMP_RESTORE..."
    # rm -rf "$TMP_RESTORE"
    # mkdir -p "$TMP_RESTORE"

    # # Restore as root to ensure metadata is written correctly
    # log "🧪 Restoring latest snapshot to $TMP_RESTORE..."
    # sudo -E restic -r "$REPO" restore latest --target "$TMP_RESTORE" | tee -a "$LOGFILE"

    # # Verify that the restore directory is not empty
    # if [ -z "$(ls -A "$TMP_RESTORE")" ]; then
    #     log "❌ ERROR: Restore test resulted in an empty directory!"
    # else
    #     log "✅ Restore test successful. Contents are now owned by '$USER' and visible in $TMP_RESTORE"
    # fi

    log "=== Finished Docker volumes backup ==="
}

# A function to ensure the final local backup repository is owned by the user who ran the script.
set_ownership() {
    local backup_dir="$1"
    
    # Determine the original non-root user who ran the script.
    local original_user="${SUDO_USER:-$USER}"
    
    # We use 'echo' here directly because we don't have a specific LOGFILE for this final action.
    # The output will still appear on your screen.
    echo "[$(timestamp)] 🙍 Applying final ownership of '$backup_dir' to user '$original_user'..."
    
    # Use sudo to change ownership of all files inside, including those created by root.
    sudo chown -R "$original_user:$original_user" "$backup_dir"
    
    echo "[$(timestamp)] ✅ Ownership set."
}


# === Repo list ===
# backup_repo "$RESTIC_BASE_REPO/Notes" \
#             "/home/k/Desktop/Notes" \
#             "notes" \
#             "/home/k/Desktop/restic_restore/Notes" \
#             "--keep-last 50" \
#             "/home/k/Desktop/notes_backup.log"

# backup_repo "$RESTIC_BASE_REPO/Secrets" \
#             "/data/secrets" \
#             "secrets" \
#             "/home/k/Desktop/restic_restore/Secrets" \
#             "--keep-last 10" \
#             "/home/k/Desktop/secrets_backup.log"

# backup_repo "$RESTIC_BASE_REPO/Scripts" \
#             "/data/scripts" \
#             "scripts" \
#             "/home/k/Desktop/restic_restore/Scripts" \
#             "--keep-last 50" \
#             "/home/k/Desktop/scripts_backup.log"

# backup_repo "$RESTIC_BASE_REPO/Other" \
#             "/data/other" \
#             "other" \
#             "/home/k/Desktop/restic_restore/Other" \
#             "--keep-last 10" \
#             "/home/k/Desktop/other_backup.log"

backup_repo "$RESTIC_BASE_REPO/Srv" \
            "/srv" \
            "srv" \
            "/home/k/Desktop/restic_restore/Srv" \
            "--keep-last 10" \
            "/home/k/Desktop/srv_backup.log"

backup_docker "$RESTIC_BASE_REPO/Docker Volumes" \
              "/var/lib/docker/volumes" \
              "docker-volume" \
              "/home/k/Desktop/restic_restore/Docker Volumes" \
              "--keep-last 10" \
              "/home/k/Desktop/docker_volumes_backup.log"

# === FINAL CLEANUP ===
# This should be the last step to ensure the user 'k' owns all the local backup files.
set_ownership "/home/k/Desktop/homelab-backup"

echo "========================="
echo "Homelab Backup Script Finished"
echo "========================="
