#!/bin/bash

# Proxmox Scheduled Snapshot Script
# Version: 1.0 (2026-05-22)
# Creates snapshots for all VMs and Containers.
# Format: S-YYYY-MM-DD
# Usage: 0 0 */2 * * /path/to/script.sh

set -e

# Ensure PATH includes Proxmox sbin directories for cron execution
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Configuration
SNAP_NAME="S-$(date +%Y-%m-%d)"
DESCRIPTION="Automated snapshot $(date +%Y-%m-%d)"
INCLUDE_RAM=0 # 0 = No RAM (fast), 1 = Include RAM (slow, more space)
SLEEP_DELAY=60 # Seconds to wait between snapshots to reduce IO stress
RETENTION_DAYS=30 # Days to keep snapshots

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

cleanup_old_snapshots() {
    local vmid=$1
    local type=$2 # qm or pct
    local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y%m%d)

    log "[-] Checking for old snapshots for $vmid..."
    
    # Extract snapshots starting with 'S-' and having the date format
    local snaps=$($type listsnapshot $vmid | awk '/^S-[0-9]{4}-[0-9]{2}-[0-9]{2}/ {print $1}')
    
    for snap in $snaps; do
        # Convert S-YYYY-MM-DD to YYYYMMDD for comparison
        local snap_date_str=$(echo $snap | cut -d'-' -f2-4 | sed 's/-//g')
        
        if [[ "$snap_date_str" =~ ^[0-9]{8}$ ]] && [ "$snap_date_str" -lt "$cutoff_date" ]; then
            log "    [!] Snapshot $snap is older than $RETENTION_DAYS days. Deleting..."
            if $type delsnapshot $vmid "$snap"; then
                log "    [OK] Deleted $snap."
            else
                log "    [ERROR] Failed to delete $snap."
            fi
        fi
    done
}

log "--- Starting Automated Snapshots (Safe Mode: ${SLEEP_DELAY}s delay) ---"

# 1. Snapshot Virtual Machines (QEMU)
VMS=$(qm list | awk 'NR>1 {print $1}')
for vmid in $VMS; do
    log "[+] Processing VM $vmid..."
    
    # Check if snapshot already exists
    if qm listsnapshot $vmid | grep -q "$SNAP_NAME"; then
        log "    [!] Snapshot $SNAP_NAME already exists for VM $vmid. Skipping."
    else
        # Perform snapshot
        if qm snapshot $vmid "$SNAP_NAME" --description "$DESCRIPTION" --vmstate $INCLUDE_RAM; then
            log "    [OK] VM $vmid snapshotted successfully."
            log "    [Wait] Sleeping for $SLEEP_DELAY seconds..."
            sleep $SLEEP_DELAY
        else
            log "    [ERROR] Failed to snapshot VM $vmid."
        fi
    fi

    # Cleanup old snapshots
    cleanup_old_snapshots $vmid "qm"
done

# 2. Snapshot Containers (LXC)
CTS=$(pct list | awk 'NR>1 {print $1}')
for vmid in $CTS; do
    log "[+] Processing Container $vmid..."
    
    # Check if snapshot already exists
    if pct listsnapshot $vmid | grep -q "$SNAP_NAME"; then
        log "    [!] Snapshot $SNAP_NAME already exists for Container $vmid. Skipping."
    else
        # Perform snapshot
        if pct snapshot $vmid "$SNAP_NAME" --description "$DESCRIPTION"; then
            log "    [OK] Container $vmid snapshotted successfully."
            log "    [Wait] Sleeping for $SLEEP_DELAY seconds..."
            sleep $SLEEP_DELAY
        else
            log "    [ERROR] Failed to snapshot Container $vmid."
        fi
    fi

    # Cleanup old snapshots
    cleanup_old_snapshots $vmid "pct"
done

log "--- All Snapshot Tasks Completed ---"
