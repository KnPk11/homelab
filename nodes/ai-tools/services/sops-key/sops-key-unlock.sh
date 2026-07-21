#!/bin/bash
# sops-key-unlock.sh — Unlock Master Admin age key into RAM for temporary SOPS operations
set -e

RAM_KEY_PATH="/dev/shm/.sops_master_key"
STATE_FILE="/dev/shm/.sops_unlock.state"
DEFAULT_KEY_LINK="$HOME/.config/sops/age/keys.txt"
DEFAULT_TTL_MINUTES=15

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [ -f "$RAM_KEY_PATH" ]; then
    echo "SOPS Master Admin key is ALREADY unlocked in memory."
    echo "Use 'sops-key-lock' to lock it, or 'sops-key-status' to check TTL."
    exit 0
fi

echo "=========================================================="
echo "          SOPS MASTER ADMIN KEY UNLOCK (RAM ONLY)        "
echo "=========================================================="
echo "Paste your Master Admin age secret key (starts with AGE-SECRET-KEY-1...):"
read -rs MASTER_KEY
echo ""

if [[ ! "$MASTER_KEY" =~ ^AGE-SECRET-KEY-1[A-Za-z0-9]+ ]]; then
    echo "ERROR: Invalid age secret key format! Must start with AGE-SECRET-KEY-1..."
    exit 1
fi

# Ensure default sops age directory exists and symlink points to RAM key
mkdir -p "$HOME/.config/sops/age"
ln -sfn "$RAM_KEY_PATH" "$DEFAULT_KEY_LINK"

# Write key directly to RAM-backed filesystem (/dev/shm)
umask 077
echo "$MASTER_KEY" > "$RAM_KEY_PATH"
chmod 600 "$RAM_KEY_PATH"

NOW=$(date +%s)
TTL_SECONDS=$((DEFAULT_TTL_MINUTES * 60))
cat << EOF > "$STATE_FILE"
UNLOCK_TS=$NOW
TTL_SECONDS=$TTL_SECONDS
EOF
chmod 600 "$STATE_FILE"

echo "Success! SOPS Master Admin Key loaded into RAM (/dev/shm)."
echo "TTL set to ${DEFAULT_TTL_MINUTES} minutes."
echo "You can now run 'sops' commands directly in any terminal window without typing passwords!"
