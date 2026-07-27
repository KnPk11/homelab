#!/bin/bash
# =============================================================================
# sops-key-lock.sh
# Version: 1.0
# Date: 2026-07-21
#
# Lock/wipe the Master Admin age key from RAM (/dev/shm) and remove agent env files.
#
# Usage:
#   sops-key-lock
# =============================================================================
set -e

RAM_KEY_PATH="/dev/shm/.sops_master_key"
STATE_FILE="/dev/shm/.sops_unlock.state"
ENV_FILE="$HOME/.sops-agent.sh"

if [ -f "$RAM_KEY_PATH" ]; then
    # Overwrite with zeros before removing
    dd if=/dev/zero of="$RAM_KEY_PATH" bs=1k count=1 2>/dev/null || true
    rm -f "$RAM_KEY_PATH"
fi

rm -f "$STATE_FILE"
rm -f "$ENV_FILE"

echo "SOPS Master Admin key has been securely locked and wiped from RAM."
