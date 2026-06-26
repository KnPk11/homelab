#!/bin/bash

# CONFIG
CACHE_SIZE="2G"
CACHE_TYPE="tmpfs"  # Options: tmpfs or zram
MOUNT_POINT="/mnt/ramcache"
BIND_PATHS=("/var/log" "/tmp" "/var/lib/docker/tmp")

# FUNCTIONS
setup_tmpfs() {
    echo "[*] Mounting tmpfs at $MOUNT_POINT..."
    sudo mkdir -p "$MOUNT_POINT"
    sudo mount -t tmpfs -o size=$CACHE_SIZE tmpfs "$MOUNT_POINT"
}

setup_zram() {
    echo "[*] Setting up zram block device..."
    sudo modprobe zram
    echo $CACHE_SIZE | sudo tee /sys/block/zram0/disksize
    sudo mkfs.ext4 /dev/zram0
    sudo mkdir -p "$MOUNT_POINT"
    sudo mount /dev/zram0 "$MOUNT_POINT"
}

bind_paths() {
    for path in "${BIND_PATHS[@]}"; do
        name=$(basename "$path")
        target="$MOUNT_POINT/$name"
        echo "[*] Binding $path → $target"
        sudo mkdir -p "$target"
        sudo mount --bind "$target" "$path"
    done
}

# MAIN
echo "[*] Starting RAM cache setup..."
if [ "$CACHE_TYPE" == "tmpfs" ]; then
    setup_tmpfs
elif [ "$CACHE_TYPE" == "zram" ]; then
    setup_zram
else
    echo "[!] Unknown CACHE_TYPE: $CACHE_TYPE"
    exit 1
fi

bind_paths
echo "[✓] RAM cache active. Bound paths:"
printf ' - %s\n' "${BIND_PATHS[@]}"
