#!/bin/bash

# Copies active logs and moves rotated logs to /mnt/logs/
# Run as sudo

set -euo pipefail

LOG_ROOT="/mnt/logs"
LOG_OWNER="1000:1000"  # <-- change to your user/group

# service_name : active_log_path
declare -A SERVICES=(
    [fail2ban]="/var/log/fail2ban.log"
    [clamav]="/var/log/clamav/scan.log"
    [crowdsec]="/var/log/crowdsec.log"
)

for service in "${!SERVICES[@]}"; do
    src="${SERVICES[$service]}"
    src_dir="$(dirname "$src")"
    src_base="$(basename "$src")"
    dest_dir="${LOG_ROOT}/${service}"

    mkdir -p "$dest_dir"
    chown "$LOG_OWNER" "$dest_dir"

    # 1. Copy the active log (daemon is still writing to it)
    if [[ -f "$src" ]]; then
        cp --preserve=timestamps "$src" "$dest_dir/${src_base}"
        chown "$LOG_OWNER" "$dest_dir/${src_base}"
        chmod 0644 "$dest_dir/${src_base}"
        echo "[copy]  $src → $dest_dir/${src_base}"
    else
        echo "[skip]  $src not found"
    fi

    # 2. Move rotated logs (e.g. .log.1, .log.2.gz, .log.3.gz)
    #    These are no longer written to, so move frees space on root.
    for rotated in "${src_dir}/${src_base}."[0-9]*; do
        [[ -f "$rotated" ]] || continue
        rotated_name="$(basename "$rotated")"

        # Skip if already exists at destination (idempotent)
        if [[ -f "$dest_dir/${rotated_name}" ]]; then
            echo "[exists] $dest_dir/${rotated_name}, skipping"
            continue
        fi

        mv "$rotated" "$dest_dir/${rotated_name}"
        chown "$LOG_OWNER" "$dest_dir/${rotated_name}"
        chmod 0644 "$dest_dir/${rotated_name}"
        echo "[move]  $rotated → $dest_dir/${rotated_name}"
    done
done
