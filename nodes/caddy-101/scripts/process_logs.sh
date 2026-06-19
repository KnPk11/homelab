#!/bin/bash
: '
Unified Log Manager v1
--------------------------------------
Purpose: Initial iteration for log rotation, archival, and retention.
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
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/process_logs.env"
TIMESTAMP="$(date +%F_%H%M%S)"

echo "--- Starting Log Process: $TIMESTAMP ---"

# 1. PERMISSIONS & DIRECTORY PREP
mkdir -p "$ARCHIVE_ROOT"
if [ -d "$LOG_ROOT/caddy" ]; then
    echo "[Debug] Ensuring Caddy folder permissions..."
    chmod -R 777 "$LOG_ROOT/caddy"
    chown -R $LOG_USER:$LOG_GROUP "$LOG_ROOT/caddy"
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

# 3. SYSTEM SERVICES: Fail2ban, Crowdsec, ClamAV
declare -A SERVICES=(
    [fail2ban]="/var/log/fail2ban.log"
    [crowdsec]="/var/log/crowdsec.log"
    [clamav]="/var/log/clamav/scan.log"
)

for svc in "${!SERVICES[@]}"; do
    SRC="${SERVICES[$svc]}"
    if [[ -f "$SRC" ]]; then
        echo "[Debug] Processing System Service: $svc ($SRC)"
        ARCHIVE_SVC_DIR="$ARCHIVE_ROOT/$svc"
        mkdir -p "$ARCHIVE_SVC_DIR"
        DST_DIR="$LOG_ROOT/$svc"
        mkdir -p "$DST_DIR"

        dd if="$SRC" of="$DST_DIR/$(basename "$SRC")" status=none
        dd if="$SRC" status=none | gzip > "$ARCHIVE_SVC_DIR/$(basename "$SRC" .log)-${TIMESTAMP}.gz"
        truncate -s 0 "$SRC"
        chown $LOG_USER:$LOG_GROUP "$DST_DIR/$(basename "$SRC")"
    fi
done

# 4. CUSTOM MIKROTIK LOGIC (The Debug Section)
MIKROTIK_SRC="/mnt/logs/mikrotik/mikrotik.log"
THRESHOLD=52428800 # 50MB in Bytes

echo "[Debug] Checking Mikrotik log at: $MIKROTIK_SRC"
if [[ -f "$MIKROTIK_SRC" ]]; then
    FILE_SIZE=$(stat -c%s "$MIKROTIK_SRC")
    echo "[Debug] Current Mikrotik size: $FILE_SIZE bytes (Threshold: $THRESHOLD bytes)"
    
    if [ "$FILE_SIZE" -gt "$THRESHOLD" ]; then
        echo "[Debug] Mikrotik STATUS: OVER THRESHOLD. Archiving to dedicated folder."
        MK_ARCHIVE_DIR="$ARCHIVE_ROOT/mikrotik"
        mkdir -p "$MK_ARCHIVE_DIR"
        
        dd if="$MIKROTIK_SRC" status=none | gzip > "$MK_ARCHIVE_DIR/mikrotik-${TIMESTAMP}.gz"
        truncate -s 0 "$MIKROTIK_SRC"
        echo "[Debug] Mikrotik archive created and active log truncated."
    else
        echo "[Debug] Mikrotik STATUS: UNDER THRESHOLD. Skipping archive, will be caught by Snapshot."
    fi
else
    echo "[Debug] Mikrotik log NOT FOUND at $MIKROTIK_SRC"
fi

# 5. CREATE MASTER SNAPSHOT
echo "[Snapshot] Creating global archive of active logs..."
OUTPUT="$ARCHIVE_ROOT/latest-snapshot-${TIMESTAMP}.tar.gz"
# Note: This finds .log files and bundles them
find "$LOG_ROOT" -type f -name "*.log" -not -path "*/Archive/*" | tar -czf "$OUTPUT" -C "$LOG_ROOT" --transform 's/^\.//' -T -
echo "[Debug] Snapshot saved: $(basename "$OUTPUT")"

# 6. FINAL PERMISSIONS (The Windows Visibility Fix)
echo "[Debug] Finalizing permissions for Windows/Samba..."

# Ensure the main directories exist and are owned by you
chown -R $LOG_USER:$LOG_GROUP "$LOG_ROOT"

# Force directories to 775 (Needed for Windows to "enter" folders)
find "$LOG_ROOT" -type d -exec chmod 775 {} +

# Force files to 664 (Read/Write for you, Read for others)
find "$LOG_ROOT" -type f -exec chmod 664 {} +

# SPECIFIC CADDY OVERRIDE: 
# Since you need 777 for the container to work, we re-apply it last 
# so the general '664' above doesn't break Caddy again.
if [ -d "$LOG_ROOT/caddy" ]; then
    chmod -R 777 "$LOG_ROOT/caddy"
fi

echo "--- Process Complete ---"
