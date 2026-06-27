#!/bin/bash

LOGFILE="/var/log/fail2ban.log"

# Get all currently banned IPs (from all jails)
banned_ips=$(fail2ban-client banned)

for ip in $banned_ips; do
  # Find the most recent ban log line for this IP
  ban_line=$(grep "Ban $ip" "$LOGFILE" | tail -n 1)
  if [[ -n "$ban_line" ]]; then
    timestamp=$(echo "$ban_line" | awk '{print $1 " " $2}' | sed 's/,.*//')

    # Extract jail name from the log line
    jail=$(echo "$ban_line" | awk '{print $5}')

    # Get bantime for that jail
    bantime=$(fail2ban-client get "$jail" bantime 2>/dev/null)

    echo "$timestamp - $ip - bantime ${bantime}s"
  fi
done