#!/bin/bash

# Run as sudo

# === CONFIGURATION ===
DEST_DIR="/home/k/Desktop/homelab-backup-stg"
# DATE=$(date +"%Y-%m-%d_%H-%M")
# DEST_DIR="$BACKUP_BASE/$DATE"
DOCKER_VOLUME_DIR="/var/lib/docker/volumes"
SRV_DIR="/srv"
DOCKER_BACKUP="$DEST_DIR/docker-volumes"
SRV_BACKUP="$DEST_DIR/srv"

# === PREPARE DIRECTORIES ===
echo "📁 Creating backup directories..."
mkdir -p "$DOCKER_BACKUP" "$SRV_BACKUP" || {
  echo "❌ Failed to create backup directories."
  exit 1
}

# === STOP DOCKER ===
echo "⏹️ Stopping Docker to safely read volumes..."
sudo systemctl stop docker

# === BACK UP DOCKER NAMED VOLUMES ===
echo "🗄️ Backing up Docker named volumes..."
for volume in "$DOCKER_VOLUME_DIR"/*; do
  vol_name=$(basename "$volume")
  vol_data="$volume/_data"

  if [ -d "$vol_data" ]; then
    tar_path="$DOCKER_BACKUP/${vol_name}.tar.gz"
    echo "📦 Backing up $vol_name -> $tar_path"
    sudo tar -czpf "$tar_path" -C "$vol_data" .
  else
    echo "⚠️ Skipping $vol_name — no _data directory"
  fi
done

# === BACK UP /srv SUBDIRECTORIES ===
echo "📂 Backing up bind-mounted paths under $SRV_DIR..."
for dir in "$SRV_DIR"/*; do
  [ -d "$dir" ] || continue
  dir_name=$(basename "$dir")
  tar_path="$SRV_BACKUP/${dir_name}.tar.gz"
  echo "📁 Backing up $dir_name -> $tar_path"
  sudo tar -czpf "$tar_path" -C "$dir" .
done

# === START DOCKER AGAIN ===
echo "▶️ Starting Docker..."
sudo systemctl start docker

# === DONE ===
echo "✅ All backups saved under:"
echo "   - Docker Volumes: $DOCKER_BACKUP"
echo "   - /srv Paths:     $SRV_BACKUP"
