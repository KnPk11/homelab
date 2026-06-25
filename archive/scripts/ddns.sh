#!/bin/bash

# --- Configuration ---
# Source credentials and domain info dynamically from the local GitOps directory.
# This file is automatically secured by the auto_pull_repo.sh script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/.env"

# --- Script Settings ---
LOGFILE="$HOME/ddns-update.log"
HOSTS=("ip")
# HOSTS=(
#     "@" "home" "banned" "filebrowser" "nextcloud" "jellyfin" 
#     "immich" "photoprism" "vaultwarden" "privatebin" "airflow" 
#     "webdav" "copyparty" "wazuh" "ai" "anytype" "portainer"
#     "pinchflat" "metube" "glances" "adguard" "syncthing" "wud"
#     "talk-hpb"
# )

# --- Script Logic ---

# Function for logging with a timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

log "--- DDNS update check started ---"

# 1. Get current public IP
PUBLIC_IP=$(curl -s https://api.ipify.org)

# Check if we successfully got the public IP
if [ -z "$PUBLIC_IP" ]; then
    log "ERROR: Could not retrieve public IP address. Exiting."
    exit 1
fi

# # Detect global IPv6 (not link-local)
# get_ipv6() {
#     ip -6 addr show eth0 | awk '/global/ {print $2}' | head -n1 | cut -d/ -f1
# }

# 2. Loop through each host to check and update
for HOST in "${HOSTS[@]}"; do
    # Construct the full domain name ('@' means the root domain)
    FULL_DOMAIN=$([ "$HOST" = "@" ] && echo "$DOMAIN" || echo "$HOST.$DOMAIN")

    # 3. Get the IP currently in DNS for this host using Google's public DNS
    CURRENT_DNS_IP=$(dig +short "$FULL_DOMAIN" @8.8.8.8)

    # Check if dig returned a valid IP
    if ! [[ "$CURRENT_DNS_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log "WARNING: Could not resolve a valid IP for $FULL_DOMAIN. Forcing update (this is normal for new records)."
        CURRENT_DNS_IP="" # Set to empty to force the update
    fi

    # 4. Compare and update if necessary
    if [ "$CURRENT_DNS_IP" != "$PUBLIC_IP" ]; then
        log "IP mismatch for $FULL_DOMAIN. DNS: '$CURRENT_DNS_IP', Public: '$PUBLIC_IP'. Updating..."
        
        UPDATE_URL="https://dynamicdns.park-your-domain.com/update?host=$HOST&domain=$DOMAIN&password=$PASSWORD&ip=$PUBLIC_IP"
        UPDATE_RESPONSE=$(curl -s "$UPDATE_URL")
        
        log "Update response for $FULL_DOMAIN: $UPDATE_RESPONSE"
    else
        log "IP for $FULL_DOMAIN ($PUBLIC_IP) is up to date. No action needed."
    fi

    # # --- IPv6 handling ---
    # IPV6=$(get_ipv6)

    # if [ -z "$IPV6" ]; then
    #     log "WARNING: No global IPv6 detected for $FULL_DOMAIN. Skipping IPv6 update."
    # else
    #     CURRENT_DNS_IPV6=$(dig +short AAAA "$FULL_DOMAIN" @8.8.8.8)

    #     if [[ "$CURRENT_DNS_IPV6" != "$IPV6" ]]; then
    #         log "IPv6 mismatch for $FULL_DOMAIN. DNS: '$CURRENT_DNS_IPV6', Local: '$IPV6'. Updating AAAA..."
            
    #         UPDATE_URL_V6="https://dynamicdns.park-your-domain.com/update?host=$HOST&domain=$DOMAIN&password=$PASSWORD&ip=$IPV6"
    #         UPDATE_RESPONSE_V6=$(curl -s "$UPDATE_URL_V6")

    #         log "IPv6 update response for $FULL_DOMAIN: $UPDATE_RESPONSE_V6"
    #     else
    #         log "IPv6 for $FULL_DOMAIN ($IPV6) is up to date."
    #     fi
    # fi
done

log "--- DDNS update check finished ---"