#!/bin/bash
# =============================================================================
# sops-key-status.sh
# Version: 1.0
# Date: 2026-07-21
#
# Report whether the SOPS Master Admin age key is unlocked in RAM and remaining TTL.
#
# Usage:
#   sops-key-status
# =============================================================================
RAM_KEY_PATH="/dev/shm/.sops_master_key"
STATE_FILE="/dev/shm/.sops_unlock.state"
DEFAULT_KEY_LINK="$HOME/.config/sops/age/keys.txt"

# Check if ~/.config/sops/age/keys.txt is a static file on disk instead of a RAM symlink
if [ -f "$DEFAULT_KEY_LINK" ] && [ ! -L "$DEFAULT_KEY_LINK" ]; then
    echo "SOPS Master Admin Key: LOCKED in RAM (Static key file detected on disk: $DEFAULT_KEY_LINK)"
    echo "Notice: SOPS commands will succeed using disk key, but key is NOT managed by RAM TTL."
    exit 0
fi

if [ ! -f "$RAM_KEY_PATH" ] || [ ! -f "$STATE_FILE" ]; then
    echo "SOPS Master Admin Key: LOCKED (Not loaded in RAM)"
    exit 0
fi

source "$STATE_FILE"
NOW=$(date +%s)
AGE=$((NOW - UNLOCK_TS))
LEFT=$((TTL_SECONDS - AGE))

if [ $LEFT -le 0 ]; then
    echo "SOPS Master Admin Key: EXPIRED (Awaiting watchdog cleanup)"
else
    MINS=$((LEFT / 60))
    SECS=$((LEFT % 60))
    echo "SOPS Master Admin Key: UNLOCKED in RAM"
    echo "Time Remaining: ${MINS}m ${SECS}s"
fi
