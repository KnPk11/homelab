#!/usr/bin/env bash
set -e

# Define paths
REPO_DIR="/opt/homelab-repo/nodes/dns-102/services/adguard"
ENV_FILE="${REPO_DIR}/.env"
TEMPLATE_FILE="${REPO_DIR}/AdGuardHome.template.yaml"
LIVE_FILE="/srv/adguard/AdGuardHome.yaml"

# 1. Check if the template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "❌ Error: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# 2. Check if .env exists and source it
if [[ -f "$ENV_FILE" ]]; then
    echo "🔒 Sourcing secrets from $ENV_FILE"
    # Export the vars so envsubst or sed can see them
    source "$ENV_FILE"
else
    echo "❌ Error: No .env file found at $ENV_FILE"
    echo "Please create one with ADGUARD_PASSWORD_HASH='...'"
    exit 1
fi

# 3. Ensure the password hash is provided
if [[ -z "$ADGUARD_PASSWORD_HASH" ]]; then
    echo "❌ Error: ADGUARD_PASSWORD_HASH is not set in $ENV_FILE"
    exit 1
fi

if [[ -z "$DOMAIN_NAME" ]]; then
    echo "❌ Error: DOMAIN_NAME is not set in $ENV_FILE"
    exit 1
fi

if [[ -z "$CADDY_NODE_IP" ]]; then
    echo "❌ Error: CADDY_NODE_IP is not set in $ENV_FILE"
    exit 1
fi

if [[ -z "$HOMELAB_NODE_IP" ]]; then
    echo "❌ Error: HOMELAB_NODE_IP is not set in $ENV_FILE"
    exit 1
fi

echo "📝 Injecting secrets into AdGuardHome configuration..."

# 4. Replace the placeholder and write directly to the live location.
# We use awk here to avoid delimiter collisions (bcrypt uses $, / and .)
awk -v hash="$ADGUARD_PASSWORD_HASH" \
    -v domain="$DOMAIN_NAME" \
    -v caddy_ip="$CADDY_NODE_IP" \
    -v homelab_ip="$HOMELAB_NODE_IP" '{
    gsub(/\{\{ADGUARD_PASSWORD_HASH\}\}/, hash)
    gsub(/\{\{DOMAIN_NAME\}\}/, domain)
    gsub(/\{\{CADDY_NODE_IP\}\}/, caddy_ip)
    gsub(/\{\{HOMELAB_NODE_IP\}\}/, homelab_ip)
    print
}' "$TEMPLATE_FILE" > "$LIVE_FILE"

# 5. Fix permissions (AdGuardHome usually runs as root, but double check)
chmod 644 "$LIVE_FILE"

echo "🔄 Restarting AdGuardHome service..."
systemctl restart AdGuardHome

echo "✅ Deployment complete!"
