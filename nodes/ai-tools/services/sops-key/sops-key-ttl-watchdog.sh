#!/bin/bash
# =============================================================================
# sops-key-ttl-watchdog.sh
# Version: 1.0
# Date: 2026-07-21
#
# Cron watchdog: wipe expired SOPS Master Admin key from RAM when TTL elapses.
#
# Usage:
#   */5 * * * * /opt/dev/homelab_repo/nodes/ai-tools/services/sops-key/sops-key-ttl-watchdog.sh >> /var/log/sops-key-ttl.log 2>&1
# =============================================================================
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
