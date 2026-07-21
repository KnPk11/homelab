#!/usr/bin/env bash
# =============================================================================
# capture-mikrotik-config.sh
# Version: 1.4
# Date: 2026-07-15
#
# Pulls a sanitised RouterOS config export from the MikroTik router via SSH
# and writes it to a local gitignored file for backup by scrape_secrets.sh.
#
# Runs as a cron job on ai-tools-105 every 3 hours.
#
# Cron entry:
#   0 */3 * * * /opt/dev/homelab_repo/nodes/ai-tools-105/services/mikrotik-backup/capture-mikrotik-config.sh >> /var/log/capture-mikrotik-config.log 2>&1
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — override via environment if needed
# ---------------------------------------------------------------------------
ROUTER_SSH_USER="${ROUTER_SSH_USER:-svc_backup}"
ROUTER_SSH_HOST="${ROUTER_SSH_HOST:-192.168.88.1}"
ROUTER_SSH_PORT="${ROUTER_SSH_PORT:-22}"
REPO_DIR="${REPO_DIR:-/opt/dev/homelab_repo}"
LOCAL_BACKUP_DIR="/opt/dev/secrets_vault/mikrotik-backups"
LOCAL_BACKUP="${LOCAL_BACKUP_DIR}/mikrotik-config-export-$(date +%Y%m%d-%H%M%S).rsc"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ---------------------------------------------------------------------------
# Pull config from router
# ---------------------------------------------------------------------------
log "Connecting to router ${ROUTER_SSH_USER}@${ROUTER_SSH_HOST}:${ROUTER_SSH_PORT}..."

TEMP_EXPORT=$(mktemp /tmp/mikrotik-export.XXXXXX.rsc)
trap 'rm -f "$TEMP_EXPORT"' EXIT

ROUTER_CMD=$(cat << 'EOF'
:put "# ============================================================================="
:put "# 🌐 INTERFACES & VLANS"
:put "# ============================================================================="
/interface export
:put ""
:put "# ============================================================================="
:put "# 🗺️ IP ADDRESSING & ROUTING"
:put "# ============================================================================="
/ip address export
/ip route export
:put ""
:put "# ============================================================================="
:put "# 🖥️ DHCP & STATIC LEASES"
:put "# ============================================================================="
/ip pool export
/ip dhcp-server export
:put ""
:put "# ============================================================================="
:put "# 🔎 DNS SETTINGS"
:put "# ============================================================================="
/ip dns export
:put ""
:put "# ============================================================================="
:put "# 🛡️ FIREWALL FILTER RULES"
:put "# ============================================================================="
/ip firewall filter export
:put ""
:put "# ============================================================================="
:put "# 🔄 FIREWALL NAT RULES"
:put "# ============================================================================="
/ip firewall nat export
:put ""
:put "# ============================================================================="
:put "# 🔧 FIREWALL MANGLE RULES"
:put "# ============================================================================="
/ip firewall mangle export
:put ""
:put "# ============================================================================="
:put "# 📋 FIREWALL ADDRESS LISTS"
:put "# ============================================================================="
/ip firewall address-list export
:put ""
:put "# ============================================================================="
:put "# 🌐 IPv6 FIREWALL RULES"
:put "# ============================================================================="
/ipv6 firewall export
EOF
)

ssh \
  -i ~/.ssh/id_ed25519 \
  -o IdentitiesOnly=yes \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  -p "${ROUTER_SSH_PORT}" \
  "${ROUTER_SSH_USER}@${ROUTER_SSH_HOST}" \
  "${ROUTER_CMD}" \
  > "${TEMP_EXPORT}"

# Sanity check — a valid export is never empty
if [[ ! -s "${TEMP_EXPORT}" ]]; then
  log "ERROR: Export was empty. Aborting."
  exit 1
fi

# ---------------------------------------------------------------------------
# Write local backup (directly to secrets_vault with timestamp)
# ---------------------------------------------------------------------------
mkdir -p "${LOCAL_BACKUP_DIR}"

# Get the most recent backup to check for changes
LATEST_BACKUP=$(ls -t "${LOCAL_BACKUP_DIR}"/mikrotik-config-export-*.rsc 2>/dev/null | head -n 1 || true)

hash_config() {
  grep -v "^#" "$1" | md5sum | awk '{print $1}'
}

if [[ -n "${LATEST_BACKUP}" ]]; then
  NEW_HASH=$(hash_config "${TEMP_EXPORT}")
  OLD_HASH=$(hash_config "${LATEST_BACKUP}")
  
  if [[ "${NEW_HASH}" == "${OLD_HASH}" ]]; then
    log "No changes detected (hashes match exactly). Skipping."
  else
    cp "${TEMP_EXPORT}" "${LOCAL_BACKUP}"
    log "Backup updated: ${LOCAL_BACKUP}"
  fi
else
  cp "${TEMP_EXPORT}" "${LOCAL_BACKUP}"
  log "Backup updated: ${LOCAL_BACKUP}"
fi

# Clean up backups older than 30 days
find "${LOCAL_BACKUP_DIR}" -type f -name "mikrotik-config-export-*.rsc" -mtime +30 -delete
log "Cleaned up backups older than 30 days."
