#!/bin/bash
# Run this script once (as sudo) to create your Kopia repository.
# Also run your main backup script in maintenance mode before any backups, to set policies.

# 1. Define your new config path
NEW_CONFIG_DIR="/opt/scripts/Backups/Kopia/config"
NEW_CONFIG_FILE="$NEW_CONFIG_DIR/main-repo.config"
REPO_PATH="/mnt/nas/Apps/Kopia/homelab-backup"
LOG_DIR="/opt/scripts/Backups/Kopia/logs"
LOG_FILE="$LOG_DIR/backup.log"

# 2. Create the directories (owned by root)
sudo mkdir -p "$NEW_CONFIG_DIR"
sudo mkdir -p "$LOG_DIR"

# 3. Create the repository using this new config path
sudo kopia repository create filesystem \
  --path="$REPO_PATH" \
  --config-file="$NEW_CONFIG_FILE"

# 4. Touch the log file so it exists
sudo touch "$LOG_FILE"