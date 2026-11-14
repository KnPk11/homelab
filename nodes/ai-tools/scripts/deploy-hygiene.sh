#!/usr/bin/env bash
# Deploy disk and log hygiene on ai-tools (CT 105):
# - Links /usr/local/sbin/prune-vscode-server.sh
# - Schedules periodic VS Code Server cleanup via /etc/cron.d/prune-vscode-server
# - Installs logrotate rules for ai-tools cron logs under /etc/logrotate.d/ai-tools-cron
# - Caps systemd-journald disk usage under /etc/systemd/journald.conf.d/99-homelab-size.conf
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

ln -sfn "${REPO_DIR}/shared/scripts/prune-vscode-server.sh" /usr/local/sbin/prune-vscode-server.sh
install -m 644 "${SCRIPT_DIR}/logrotate-ai-tools" /etc/logrotate.d/ai-tools-cron
install -d -m 755 /etc/systemd/journald.conf.d
install -m 644 "${SCRIPT_DIR}/journald-size.conf" /etc/systemd/journald.conf.d/99-homelab-size.conf

cat > /etc/cron.d/prune-vscode-server <<'EOF'
# Keep running + 1 extra VS Code Server build on ai-tools (16G root disk)
0 3 */3 * * root /usr/local/sbin/prune-vscode-server.sh --apply --keep-extra 1 --all >> /var/log/prune-vscode-server.log 2>&1
EOF
chmod 644 /etc/cron.d/prune-vscode-server

logrotate -d /etc/logrotate.d/ai-tools-cron >/dev/null
systemctl restart systemd-journald
journalctl --vacuum-size=100M
echo "ai-tools hygiene deployed cleanly."
