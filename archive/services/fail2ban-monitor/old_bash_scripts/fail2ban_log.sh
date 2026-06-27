#!/bin/bash

LOGFILE="/var/log/fail2ban.log"
# Get current time in seconds since epoch
now=$(date +%s)
# Set cutoff to 1 days ago
cutoff=$((now - 1*24*3600))

grep 'Ban' "$LOGFILE" | \
grep -E 'caddy-authcodes|caddy-sensitivepaths' | \
awk -v cutoff="$cutoff" '{
  split($2, timeparts, ",");
  timestamp = $1 " " timeparts[1];
  # Convert timestamp to epoch seconds
  cmd = "date -d \"" timestamp "\" +%s"
  cmd | getline ts
  close(cmd)
  if ($8 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ && ts >= cutoff) {
    print timestamp " - " $8
  }
}' | sort -r