#!/bin/bash
# =============================================================================
# fix-network.sh
# Version: 1.0
# Date: 2026-07-21
#
# Proxmox NIC recovery: if router ARP is missing on nic0, bounce the interface.
# Uses flock + 10-minute cooldown so cron can call it frequently safely.
#
# Usage:
#   */1 * * * * /path/to/fix-network.sh   # typical cron; exits quietly if locked
# =============================================================================
exec 9>/var/lock/fix-network.lock
if ! flock -n 9; then
    exit 0
fi

ROUTER_IP="192.168.50.1"
INTERFACE="nic0"

# Check if the Router's MAC address is visible in the ARP table
if ! ip neigh show $ROUTER_IP | grep -qE "REACHABLE|DELAY|STALE"; then
    echo "$(date): ARP check failed. NIC $INTERFACE likely hung." >> /var/log/network-repair.log
    /usr/sbin/ip link set $INTERFACE down
    sleep 3
    /usr/sbin/ip link set $INTERFACE up
    
    # 10-minute cooldown: script sleeps while holding the lock, 
    # causing any new cron triggers to silently exit.
    sleep 600 
fi
