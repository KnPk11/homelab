#!/bin/bash
set -e

# --- Configuration ---
SOURCE="/mnt/pool"
DEST="/mnt/flash1"
FOLDERS=("Apps" "Downloads" "Media" "Private" "Shared")

# --- Define directories to exclude (relative to the folder being backed up) ---
EXCLUDE=("AnyType" "Kopia" "Audio") 

# --- Script Start ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting rsync backup..."
echo "Source: $SOURCE"
echo "Destination: $DEST"
echo "-------------------------------------"

# --- Build the --exclude flags for rsync ---
EXCLUDE_FLAGS=()
for item in "${EXCLUDE[@]}"; do
    EXCLUDE_FLAGS+=("--exclude=$item")
done

# Loop through each folder in the FOLDERS array
for folder in "${FOLDERS[@]}"; do
    src_path="$SOURCE/$folder/"
    dest_path="$DEST/$folder/"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backing up '$folder'..."
    
    # Run the rsync command with the dynamically generated exclude flags
    rsync -avh --delete --delete-excluded "${EXCLUDE_FLAGS[@]}" "$src_path" "$dest_path"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished backing up '$folder'."
    echo ""
done

echo "-------------------------------------"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] All backups finished successfully!"