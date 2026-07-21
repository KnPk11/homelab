#!/bin/bash
# sops-key-status.sh — Check status of SOPS Master Admin key TTL
RAM_KEY_PATH="/dev/shm/.sops_master_key"
STATE_FILE="/dev/shm/.sops_unlock.state"

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
