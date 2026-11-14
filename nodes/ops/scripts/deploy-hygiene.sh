#!/usr/bin/env bash
# Deploy disk and log hygiene on ops (CT 112):
# - Links /usr/local/sbin/prune-vscode-server.sh
# - Schedules periodic VS Code Server cleanup via /etc/cron.d/prune-vscode-server
# - Installs logrotate rules for ops cron logs under /etc/logrotate.d/ops-cron
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

ln -sfn "${REPO_DIR}/shared/scripts/prune-vscode-server.sh" /usr/local/sbin/prune-vscode-server.sh
install -m 644 "${SCRIPT_DIR}/logrotate-ops" /etc/logrotate.d/ops-cron

cat > /etc/cron.d/prune-vscode-server <<'EOF'
# Keep only running/latest VS Code Server build on ops (3.9G root disk)
0 3 */3 * * root /usr/local/sbin/prune-vscode-server.sh --apply --keep-extra 0 --all >> /var/log/prune-vscode-server.log 2>&1
EOF
chmod 644 /etc/cron.d/prune-vscode-server

logrotate -d /etc/logrotate.d/ops-cron >/dev/null
echo "ops hygiene deployed cleanly."
