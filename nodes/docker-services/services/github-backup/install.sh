#!/usr/bin/env bash
# =============================================================================
# install.sh
# Version: 1.0
# Description: Install GitHub backup script, configuration, service, and timer
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

echo "[+] Creating runtime configuration directory /srv/github-backup..."
mkdir -p /srv/github-backup
cp "$SCRIPT_DIR/conf.yml" /srv/github-backup/conf.yml
chmod 644 /srv/github-backup/conf.yml

if [[ ! -f /srv/github-backup/.env ]]; then
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        cp "$SCRIPT_DIR/.env" /srv/github-backup/.env
    else
        echo "[!] Notice: /srv/github-backup/.env does not exist. Please populate GITHUB_TOKEN."
    fi
fi
chmod 600 /srv/github-backup/.env 2>/dev/null || true

echo "[+] Installing GitHub backup script to /usr/local/bin..."
cp "$SCRIPT_DIR/github-backup.sh" /usr/local/bin/github-backup.sh
chmod 755 /usr/local/bin/github-backup.sh

echo "[+] Installing systemd service and timer units..."
cp "$SCRIPT_DIR/github-backup.service" /etc/systemd/system/github-backup.service
cp "$SCRIPT_DIR/github-backup.timer" /etc/systemd/system/github-backup.timer
chmod 644 /etc/systemd/system/github-backup.service /etc/systemd/system/github-backup.timer

echo "[+] Reloading systemd and enabling timer..."
systemctl daemon-reload
systemctl enable --now github-backup.timer

echo "[+] GitHub backup installation complete."
systemctl status github-backup.timer --no-pager
