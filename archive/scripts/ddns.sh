#!/bin/bash

# === CONFIG ===
DOMAIN="example.com"               # Your domain
PASSWORD="your_password_here"        # Namecheap Dynamic DNS password
LOGFILE="$HOME/ddns-update.log"    # Optional log file

# List of hosts you want to update
# Use "@" for root, otherwise put the subdomain
HOSTS=("@" "home" "banned" "filebrowser" "nextcloud" "jellyfin" "photoprism" "immich" "vaultwarden" "secretbin" "pinchflat" "airflow" "webdav")

# === GET PUBLIC IP ===
IP=$(curl -s https://api.ipify.org)

# === UPDATE LOOP ===
for HOST in "${HOSTS[@]}"; do
    URL="https://dynamicdns.park-your-domain.com/update?host=$HOST&domain=$DOMAIN&password=$PASSWORD&ip=$IP"
    RESPONSE=$(curl -s "$URL")

    echo "$(date): Updated $HOST.$DOMAIN to $IP" >> "$LOGFILE"
    echo "$RESPONSE" >> "$LOGFILE"
done