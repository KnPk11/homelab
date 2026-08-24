#!/usr/bin/env bash
# =============================================================================
# update-namecheap-ddns.sh
# Version: 2.0
#
# Namecheap Dynamic DNS update script for keeping the WAN locator record
# (e.g. ip.example.com) synchronised with your current public IPv4 address.
# Designed to run via cron on ai-tools.
# =============================================================================

set -euo pipefail

# 1. Locate and source configuration
ENV_FILE="${DDNS_ENV_FILE:-/srv/namecheap-ddns/ddns.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$SCRIPT_DIR/ddns.env" ]]; then
    ENV_FILE="$SCRIPT_DIR/ddns.env"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Configuration file not found at $ENV_FILE" >&2
    exit 1
  fi
fi

# Source environment
# shellcheck source=/dev/null
source "$ENV_FILE"

# Required variables
DOMAIN="${DOMAIN:-}"
PASSWORD="${PASSWORD:-}"
LOGFILE="${LOGFILE:-$HOME/namecheap-ddns.log}"

# Default hosts to update (e.g. 'ip')
if [[ -z "${HOSTS:-}" ]]; then
  HOST_LIST=("ip")
elif [[ "$(declare -p HOSTS 2>/dev/null)" =~ "declare -a" ]]; then
  HOST_LIST=("${HOSTS[@]}")
else
  IFS=', ' read -r -a HOST_LIST <<< "$HOSTS"
fi

if [[ -z "$DOMAIN" || -z "$PASSWORD" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: DOMAIN and PASSWORD must be defined in $ENV_FILE" >&2
  exit 1
fi

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  if [[ -n "$LOGFILE" ]]; then
    mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || true
    echo "$msg" >> "$LOGFILE" 2>/dev/null || true
  fi
}

# 2. Retrieve current public IPv4 address
get_public_ip() {
  local ip
  ip=$(curl -fs4 --max-time 10 https://api.ipify.org 2>/dev/null) || \
  ip=$(curl -fs4 --max-time 10 https://icanhazip.com 2>/dev/null) || \
  ip=$(curl -fs4 --max-time 10 https://ifconfig.me 2>/dev/null) || true
  
  ip=$(echo "$ip" | tr -d '[:space:]')
  if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "$ip"
  else
    echo ""
  fi
}

PUBLIC_IP=$(get_public_ip)
if [[ -z "$PUBLIC_IP" ]]; then
  log "ERROR: Could not retrieve valid public IPv4 address. Aborting."
  exit 1
fi

# 3. Check and update records
for HOST in "${HOST_LIST[@]}"; do
  [[ -z "$HOST" ]] && continue
  
  if [[ "$HOST" == "@" ]]; then
    FULL_DOMAIN="$DOMAIN"
  else
    FULL_DOMAIN="${HOST}.${DOMAIN}"
  fi

  # Query public DNS resolver
  CURRENT_DNS_IP=$(dig +short "$FULL_DOMAIN" @1.1.1.1 2>/dev/null | tail -n1 || true)
  if ! [[ "$CURRENT_DNS_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    CURRENT_DNS_IP=$(dig +short "$FULL_DOMAIN" @8.8.8.8 2>/dev/null | tail -n1 || true)
  fi

  if [[ "$CURRENT_DNS_IP" == "$PUBLIC_IP" ]]; then
    log "Record for $FULL_DOMAIN ($PUBLIC_IP) is up to date. No update required."
    continue
  fi

  log "IP mismatch for $FULL_DOMAIN. Current DNS: '${CURRENT_DNS_IP:-<unresolved>}', Public IP: '$PUBLIC_IP'. Updating Namecheap..."

  UPDATE_URL="https://dynamicdns.park-your-domain.com/update?host=${HOST}&domain=${DOMAIN}&password=${PASSWORD}&ip=${PUBLIC_IP}"
  RESPONSE=$(curl -fs --max-time 15 "$UPDATE_URL" 2>/dev/null || true)

  if [[ "$RESPONSE" =~ "<ErrCount>0</ErrCount>" ]]; then
    log "SUCCESS: Successfully updated $FULL_DOMAIN to $PUBLIC_IP"
  else
    log "WARNING: Namecheap update returned response: $RESPONSE"
  fi
done
