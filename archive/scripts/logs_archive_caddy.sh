#!/bin/bash

# Moves logrotated Caddy logs into the Archive directory
# Also compresses logs that Caddy has failed compressing

# Run as sudo

set -euo pipefail
shopt -s nullglob

SOURCE_BASE="/mnt/logs/caddy"
ARCHIVE_BASE="/mnt/logs/Archive/caddy"

# 1. Find and compress ONLY timestamped logs
# Logic: Look for files ending in .log that contain a '-' followed by a number (the start of the year 20xx)
# This specifically avoids 'access.log' or 'error.log'
find "$SOURCE_BASE" -type f -regextype posix-egrep -regex ".*-[0-9]{4}.*\.log$" | while read -r file; do
    echo "Compressing rotated log: $(basename "$file")"
    gzip -f "$file"
done

# 2. Move successfully compressed files to the archive
# We only move files with size > 0 to avoid those 'ghost' files
find "$SOURCE_BASE" -type f -name "*.log.gz" -size +0 | while read -r file; do
    
    RELATIVE_PATH="${file#$SOURCE_BASE/}"
    DEST_DIR="$ARCHIVE_BASE/$(dirname "$RELATIVE_PATH")"
    
    mkdir -p "$DEST_DIR"
    
    mv "$file" "$DEST_DIR/"
    echo "Archived: $RELATIVE_PATH"
done

# 3. Cleanup: Remove any 0-byte .gz files left behind by Caddy's failed attempts
find "$SOURCE_BASE" -type f -name "*.log.gz" -size 0 -delete
