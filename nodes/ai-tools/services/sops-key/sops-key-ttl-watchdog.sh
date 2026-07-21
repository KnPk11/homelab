#!/bin/bash
# sops-key-ttl-watchdog.sh — Watchdog run via cron to automatically wipe expired SOPS keys from RAM
RAM_KEY_PATH="/dev/shm/.sops_master_key"
STATE_FILE="/dev/shm/.sops_unlock.state"

if [ -f "$RAM_KEY_PATH" ] && [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
    NOW=$(date +%s)
    AGE=$((NOW - UNLOCK_TS))
    LEFT=$((TTL_SECONDS - AGE))
    
    if [ $LEFT -le 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] SOPS Key TTL expired. Wiping key from RAM..." >> /var/log/sops-key-ttl.log
        /usr/local/bin/sops-key-lock || true
    fi
fi
