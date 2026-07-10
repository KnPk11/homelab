#!/bin/bash
: '
Unified Log Manager - LXC Edition
--------------------------------------
Purpose: Manages log rotation, archival, and retention for the Caddy LXC environment.
Requirements: Must be run as root.
Usage: Usually executed via cron.
'

set -euo pipefail
shopt -s nullglob

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)" 
   exit 1
fi

# --- Configuration ---
LOG_ROOT="/mnt/logs/current"
ARCHIVE_ROOT="/mnt/logs/archive"
LOG_USER="1000"
LOG_GROUP="1000"
SNAPSHOT_KEEP_COUNT=1
LOG_RETENTION_DAYS=365

TIMESTAMP="$(date +%F_%H%M%S)"

echo "--- Starting Log Process: $TIMESTAMP ---"

# 1. PERMISSIONS & DIRECTORY PREP
mkdir -p "$ARCHIVE_ROOT"
if [ -d "$LOG_ROOT/caddy" ]; then
    echo "[Debug] Ensuring Caddy folder permissions..."
    chmod -R 777 "$LOG_ROOT/caddy"
    chown -R caddy:caddy "$LOG_ROOT/caddy"
fi

# 2. CADDY: Move rotated logs
echo "[Debug] Checking for rotated Caddy logs..."
find "$LOG_ROOT/caddy" -type f -regextype posix-egrep -regex ".*-[0-9]{4}.*\.log$" -exec gzip -f {} +
find "$LOG_ROOT/caddy" -type f -name "*.log.gz" -size +0 | while read -r file; do
    REL_PATH="${file#$LOG_ROOT/caddy/}"
    DEST_DIR="$ARCHIVE_ROOT/caddy/$(dirname "$REL_PATH")"
    mkdir -p "$DEST_DIR"
    mv "$file" "$DEST_DIR/"
done

# 3. SYSTEM SERVICES: Fail2ban, Crowdsec
declare -A SERVICES=(
    [fail2ban]="/var/log/fail2ban.log"
    [crowdsec]="/var/log/crowdsec.log"
)

for svc in "${!SERVICES[@]}"; do
    SRC="${SERVICES[$svc]}"
    if [[ -f "$SRC" ]]; then
        echo "[Debug] Processing System Service: $svc ($SRC)"
        ARCHIVE_SVC_DIR="$ARCHIVE_ROOT/$svc"
        mkdir -p "$ARCHIVE_SVC_DIR"
        DST_DIR="$LOG_ROOT/$svc"
        mkdir -p "$DST_DIR"

        cp "$SRC" "$DST_DIR/$(basename "$SRC")"
        gzip -c "$SRC" > "$ARCHIVE_SVC_DIR/$(basename "$SRC" .log)-${TIMESTAMP}.gz"
        truncate -s 0 "$SRC"
        chown $LOG_USER:$LOG_GROUP "$DST_DIR/$(basename "$SRC")"
    fi
done

# 4. CUSTOM MIKROTIK LOGIC
MIKROTIK_SRC="$LOG_ROOT/mikrotik/mikrotik.log"
THRESHOLD=52428800 # 50MB

echo "[Debug] Checking Mikrotik log at: $MIKROTIK_SRC"
if [[ -f "$MIKROTIK_SRC" ]]; then
    FILE_SIZE=$(stat -c%s "$MIKROTIK_SRC")
    if [ "$FILE_SIZE" -gt "$THRESHOLD" ]; then
        echo "[Debug] Mikrotik OVER THRESHOLD. Archiving."
        MK_ARCHIVE_DIR="$ARCHIVE_ROOT/mikrotik"
        mkdir -p "$MK_ARCHIVE_DIR"
        gzip -c "$MIKROTIK_SRC" > "$MK_ARCHIVE_DIR/mikrotik-${TIMESTAMP}.gz"
        truncate -s 0 "$MIKROTIK_SRC"
    fi
fi

# 5. CREATE MASTER SNAPSHOT
echo "[Snapshot] Creating global archive of active logs..."
OUTPUT="$ARCHIVE_ROOT/latest-snapshot-${TIMESTAMP}.tar.gz"
LOG_LIST=$(mktemp)
find "$LOG_ROOT" -type f -name "*.log" 2>/dev/null > "$LOG_LIST" || true
if [ -s "$LOG_LIST" ]; then
    tar -czf "$OUTPUT" -C "$LOG_ROOT" --transform "s/^\.//" -T "$LOG_LIST"
fi
rm -f "$LOG_LIST"

# 6. RETENTION (Cleanup)
echo "[Cleanup] Enforcing Master Snapshot retention (keeping $SNAPSHOT_KEEP_COUNT)..."
ls -t "$ARCHIVE_ROOT"/latest-snapshot-*.tar.gz 2>/dev/null | tail -n +$(($SNAPSHOT_KEEP_COUNT + 1)) | while read -r snapshot; do
    echo "[Cleanup] Deleting old snapshot: $snapshot"
    rm -f "$snapshot"
done

echo "[Cleanup] Removing individual archives older than $LOG_RETENTION_DAYS days..."
find "$ARCHIVE_ROOT" -type f -name "*.gz" -not -name "latest-snapshot-*" -mtime +$LOG_RETENTION_DAYS -delete

# 7. FINAL PERMISSIONS
echo "[Debug] Finalizing permissions..."
for dir in "$LOG_ROOT/caddy" "$LOG_ROOT/fail2ban" "$LOG_ROOT/crowdsec" "$LOG_ROOT/mikrotik" "$ARCHIVE_ROOT"; do
    if [ -d "$dir" ]; then
        chown -R "$LOG_USER:$LOG_GROUP" "$dir"
        find "$dir" -type d -exec chmod 775 {} +
        find "$dir" -type f -exec chmod 664 {} +
    fi
done

if [ -d "$LOG_ROOT/caddy" ]; then
    chown -R caddy:caddy "$LOG_ROOT/caddy"
    chmod -R 777 "$LOG_ROOT/caddy"
fi

echo "--- Process Complete ---"
