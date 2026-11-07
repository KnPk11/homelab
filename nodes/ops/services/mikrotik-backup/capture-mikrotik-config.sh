#!/usr/bin/env bash
# =============================================================================
# capture-mikrotik-config.sh
# Version: 1.6
# Date: 2026-11-07
#
# capture-mikrotik-config.sh — Exports MikroTik RouterOS config via SSH
# and writes it to a local backup directory for automated retention and scraping.
#
# Runs as a cron job on ops (CT 112) every 3 hours.
#
# Usage:
#   # cron on ops
#   0 */3 * * * /opt/homelab-repo/nodes/ops/services/mikrotik-backup/capture-mikrotik-config.sh >> /var/log/capture-mikrotik-config.log 2>&1
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — override via environment if needed
# ---------------------------------------------------------------------------
ROUTER_SSH_USER="${ROUTER_SSH_USER:-svc_backup}"
ROUTER_SSH_HOST="${ROUTER_SSH_HOST:-192.168.88.1}"
ROUTER_SSH_PORT="${ROUTER_SSH_PORT:-22}"
# Passwordless job key (NOT God Mode, NOT the GitHub key). Cron has no ssh-agent.
ROUTER_SSH_IDENTITY="${ROUTER_SSH_IDENTITY:-$HOME/.ssh/id_ed25519_mt_backup}"
REPO_DIR="${REPO_DIR:-/opt/homelab-repo}"
LOCAL_BACKUP_DIR="${LOCAL_BACKUP_DIR:-/srv/mikrotik-backup/backups}"
LOCAL_BACKUP="${LOCAL_BACKUP_DIR}/mikrotik-config-export-$(date +%Y%m%d-%H%M%S).rsc"
RETENTION_DAYS="${RETENTION_DAYS:-90}"

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

if [[ ! -f "${ROUTER_SSH_IDENTITY}" ]]; then
  log "ERROR: SSH identity not found: ${ROUTER_SSH_IDENTITY}"
  log "This job needs a passphrase-less key for ${ROUTER_SSH_USER} (default ~/.ssh/id_ed25519_mt_backup)."
  exit 1
fi

ssh \
  -i "${ROUTER_SSH_IDENTITY}" \
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
# Update Git repository & push to Gitea
# ---------------------------------------------------------------------------
GIT_REPO_DIR="${GIT_REPO_DIR:-/srv/mikrotik-config}"
CONFIG_TARGET="${GIT_REPO_DIR}/mikrotik-config.rsc"

hash_config() {
  grep -v "^#" "$1" | md5sum | awk '{print $1}'
}

if [[ -d "${GIT_REPO_DIR}/.git" ]]; then
  NEW_HASH=$(hash_config "${TEMP_EXPORT}")
  OLD_HASH=""
  if [[ -f "${CONFIG_TARGET}" ]]; then
    OLD_HASH=$(hash_config "${CONFIG_TARGET}")
  fi

  if [[ "${NEW_HASH}" == "${OLD_HASH}" ]]; then
    log "No changes detected (hashes match exactly). Skipping."
  else
    cp "${TEMP_EXPORT}" "${CONFIG_TARGET}"
    chmod 600 "${CONFIG_TARGET}"
    git -C "${GIT_REPO_DIR}" add mikrotik-config.rsc
    git -C "${GIT_REPO_DIR}" commit -m "chore(router): auto-capture $(date '+%Y-%m-%d %H:%M:%S')"
    git -C "${GIT_REPO_DIR}" push origin main
    log "Backup committed and pushed to Gitea (kp/mikrotik-config)."
  fi
else
  log "WARNING: Git repository not found at ${GIT_REPO_DIR}."
fi

# ---------------------------------------------------------------------------
# Write local fallback backup (directly to /srv/mikrotik-backup/backups with timestamp)
# ---------------------------------------------------------------------------
mkdir -p "${LOCAL_BACKUP_DIR}"

LATEST_BACKUP=$(ls -t "${LOCAL_BACKUP_DIR}"/mikrotik-config-export-*.rsc 2>/dev/null | head -n 1 || true)

if [[ -n "${LATEST_BACKUP}" ]]; then
  NEW_HASH=$(hash_config "${TEMP_EXPORT}")
  OLD_HASH=$(hash_config "${LATEST_BACKUP}")
  
  if [[ "${NEW_HASH}" != "${OLD_HASH}" ]]; then
    cp "${TEMP_EXPORT}" "${LOCAL_BACKUP}"
    chmod 600 "${LOCAL_BACKUP}"
    log "Fallback backup updated: ${LOCAL_BACKUP}"
  fi
else
  cp "${TEMP_EXPORT}" "${LOCAL_BACKUP}"
  chmod 600 "${LOCAL_BACKUP}"
  log "Fallback backup updated: ${LOCAL_BACKUP}"
fi

# Clean up backups older than 90 days
find "${LOCAL_BACKUP_DIR}" -type f -name "mikrotik-config-export-*.rsc" -mtime "+${RETENTION_DAYS}" -delete
