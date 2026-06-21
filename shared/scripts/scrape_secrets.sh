#!/bin/bash
# Description: Scrapes and backs up all .env files from homelab nodes.
# Usage: Run via cron (e.g., weekly) on the management node or NAS.

BACKUP_DIR="/root/secrets_vault/backups"

# Map Hostnames to IPs (For all nodes)
declare -A NODES=(
    ["caddy-101"]="192.168.50.101"
    ["omv-90"]="192.168.50.90"
    ["proxmox-100"]="192.168.50.100"
    ["homelab-95"]="192.168.50.95"
    ["openclaw-91"]="192.168.50.91"
)

# Nodes that use the automated rsync GitOps approach
GITOPS_HOSTS=("caddy-101" "omv-90" "proxmox-100")

echo "Starting secrets backup... $(date)"

for HOST in "${GITOPS_HOSTS[@]}"; do
    IP="${NODES[$HOST]}"
    echo "Scraping secrets from $HOST ($IP)..."
    
    HOST_DIR="$BACKUP_DIR/$HOST"
    mkdir -p "$HOST_DIR"
    
    # Rsync magic: grab only .env files from their specific node folder in the repo
    rsync -avm --include='*.env' --include='*/' --exclude='*' "root@$IP:/opt/homelab-repo/nodes/$HOST/" "$HOST_DIR/"
    
    if [ $? -eq 0 ]; then
        echo "Successfully backed up $HOST"
    else
        echo "Warning: Failed to back up $HOST"
    fi
done

# Legacy/Specific Nodes:
echo "Backing up homelab-95 (legacy)..."
HOMELAB_95_DIR="$BACKUP_DIR/homelab-95/secrets"
mkdir -p "$HOMELAB_95_DIR"
FILES=(
    "airflow_fernet_key" "airflow_jwt_secret" "airflow_webui_password" "ddns.conf" "filebrowser_password" "gcp-creds.json"
    "glances.pwd" "grafana_password" "immich_database_password" "influxdb_password" "kopia.env" "mediamtx_password" "n8n_password"
    "n8n_secret_key" "nextcloud_hpb_secrets.env" "nextcloud_mysql_password" "nextcloud_mysql_root_password" "owncloud_db_password"
    "owncloud_mysql_root_password" "password_standard" "password_test" "photoprism_database_password" "photoprism_mysql_root_password"
    "photoprism_password" "pihole_password" "postgres_password" "projectsend_mysql_password" "projectsend_mysql_root_password"
    "tailscale_nginx_authkey" "tubearchivist_password" "vaultwarden_admin_token" "whats-up-docker-telegram"
)
for FILE in "${FILES[@]}"; do
    ssh -o BatchMode=yes "${NODES["homelab-95"]}" "cat /data/secrets/$FILE" > "$HOMELAB_95_DIR/$FILE" 2>/dev/null || true
done

echo "Backing up openclaw-91..."
OPENCLAW_DIR="$BACKUP_DIR/openclaw-91/openclaw"
mkdir -p "$OPENCLAW_DIR"
ssh -o BatchMode=yes "${NODES["openclaw-91"]}" "cat /home/k/.openclaw/openclaw.json" > "$OPENCLAW_DIR/openclaw.json" 2>/dev/null || true

echo "Backing up hermes (on openclaw-91)..."
HERMES_DIR="$BACKUP_DIR/openclaw-91/hermes"
mkdir -p "$HERMES_DIR"
ssh -o BatchMode=yes "${NODES["openclaw-91"]}" "cat /home/k/.hermes/config.yaml" > "$HERMES_DIR/config.yaml" 2>/dev/null || true
ssh -o BatchMode=yes "${NODES["openclaw-91"]}" "cat /home/k/.hermes/.env" > "$HERMES_DIR/.env" 2>/dev/null || true
ssh -o BatchMode=yes "${NODES["openclaw-91"]}" "cat /home/k/.hermes/auth.json" > "$HERMES_DIR/auth.json" 2>/dev/null || true

# Secure the vault so only root can read it
chmod -R 600 "$BACKUP_DIR"
find "$BACKUP_DIR" -type d -exec chmod 700 {} +

echo "Secrets backup complete. Files secured in $BACKUP_DIR"
