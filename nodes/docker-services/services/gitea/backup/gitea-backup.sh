#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="/mnt/nas/Apps/gitea_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_TAG="gitea-backup"
CONTAINER_NAME="gitea"
TEMP_DUMP="/tmp/gitea-dump-${TIMESTAMP}.zip"

logger -t "$LOG_TAG" "Starting Gitea backup to $BACKUP_ROOT..."
echo "[$(date -u +'%Y-%m-%d %H:%M:%SZ')] Starting Gitea backup to $BACKUP_ROOT..."

# 1. Ensure NFS backup destination is mounted
if ! mountpoint -q /mnt/nas; then
    mount /mnt/nas || {
        logger -s -t "$LOG_TAG" "ERROR: /mnt/nas is not mounted and failed to mount."
        echo "ERROR: /mnt/nas is not mounted and failed to mount." >&2
        exit 1
    }
fi

mkdir -p "$BACKUP_ROOT"

# 2. Check Gitea container status
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    logger -s -t "$LOG_TAG" "ERROR: Container '${CONTAINER_NAME}' is not running."
    echo "ERROR: Container '${CONTAINER_NAME}' is not running." >&2
    exit 1
fi

# 3. Execute atomic gitea dump inside the container
echo "Running atomic 'gitea dump' inside container '${CONTAINER_NAME}'..."
docker exec -u git -w /tmp "$CONTAINER_NAME" gitea dump \
    --work-path /data/gitea \
    --config /data/gitea/conf/app.ini \
    --file "$TEMP_DUMP"

# 4. Copy dump archive from container to OMV storage
DEST_FILE="$BACKUP_ROOT/gitea_dump_${TIMESTAMP}.zip"

echo "Copying dump archive to $DEST_FILE..."
docker cp "${CONTAINER_NAME}:${TEMP_DUMP}" "$DEST_FILE"
chmod 644 "$DEST_FILE"

# Clean up temp file inside container
docker exec -u git "$CONTAINER_NAME" rm -f "$TEMP_DUMP"

# 5. Prune backups older than 7 days
echo "Pruning snapshots older than 7 days in $BACKUP_ROOT..."
find "$BACKUP_ROOT" -name "gitea_dump_*.zip" -type f -mtime +7 -delete || true

BACKUP_SIZE=$(ls -lh "$DEST_FILE" | awk '{print $5}')
logger -t "$LOG_TAG" "Gitea backup completed successfully. File: $DEST_FILE ($BACKUP_SIZE)"
echo "[$(date -u +'%Y-%m-%d %H:%M:%SZ')] Backup completed successfully: $DEST_FILE ($BACKUP_SIZE)"
