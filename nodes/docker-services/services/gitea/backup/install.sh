#!/usr/bin/env bash
# =============================================================================
# install.sh
# Version: 1.0
# Description: Install Gitea backup script, systemd service, and timer
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

echo "[+] Installing Gitea backup script to /usr/local/bin..."
cp "$SCRIPT_DIR/gitea-backup.sh" /usr/local/bin/gitea-backup.sh
chmod 755 /usr/local/bin/gitea-backup.sh

echo "[+] Installing systemd service and timer units..."
cp "$SCRIPT_DIR/gitea-backup.service" /etc/systemd/system/gitea-backup.service
cp "$SCRIPT_DIR/gitea-backup.timer" /etc/systemd/system/gitea-backup.timer
chmod 644 /etc/systemd/system/gitea-backup.service /etc/systemd/system/gitea-backup.timer

echo "[+] Reloading systemd and enabling timer..."
systemctl daemon-reload
systemctl enable --now gitea-backup.timer

echo "[+] Gitea backup installation complete."
systemctl status gitea-backup.timer --no-pager
