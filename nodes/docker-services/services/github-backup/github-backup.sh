#!/usr/bin/env bash
# =============================================================================
# github-backup.sh
# Version: 1.0
# Description: Automated GitHub backup runner using Gickup to OMV NFS storage
# =============================================================================
set -euo pipefail

BACKUP_ROOT="/mnt/nas/Apps/github_backups"
CONF_FILE="/srv/github-backup/conf.yml"
ENV_FILE="/srv/github-backup/.env"
LOG_TAG="github-backup"
IMAGE_NAME="buddyspencer/gickup:latest"

logger -t "$LOG_TAG" "Starting GitHub backup to $BACKUP_ROOT..."
echo "[$(date -u +'%Y-%m-%d %H:%M:%SZ')] Starting GitHub backup to $BACKUP_ROOT..."

# 1. Ensure NFS backup destination is mounted
if ! mountpoint -q /mnt/nas; then
    mount /mnt/nas || {
        logger -s -t "$LOG_TAG" "ERROR: /mnt/nas is not mounted and failed to mount."
        echo "ERROR: /mnt/nas is not mounted and failed to mount." >&2
        exit 1
    }
fi

mkdir -p "$BACKUP_ROOT"

# 2. Check configuration and secret environment
if [[ ! -f "$CONF_FILE" ]]; then
    logger -s -t "$LOG_TAG" "ERROR: Configuration file $CONF_FILE not found."
    echo "ERROR: Configuration file $CONF_FILE not found." >&2
    exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
    logger -s -t "$LOG_TAG" "ERROR: Environment file $ENV_FILE not found."
    echo "ERROR: Environment file $ENV_FILE not found." >&2
    exit 1
fi

# 3. Execute Gickup one-shot container
docker run --rm \
    --name "gickup-backup-run" \
    -v "$CONF_FILE:/gickup/conf.yml:ro" \
    -v "$BACKUP_ROOT:/backups" \
    --env-file "$ENV_FILE" \
    -e TZ="Europe/London" \
    "$IMAGE_NAME" /gickup/conf.yml

logger -t "$LOG_TAG" "GitHub backup completed successfully."
echo "[$(date -u +'%Y-%m-%d %H:%M:%SZ')] GitHub backup completed successfully."
