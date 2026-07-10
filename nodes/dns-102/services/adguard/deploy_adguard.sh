#!/usr/bin/env bash
set -e

# Secrets live under /srv/adguard/ (not in the disposable GitOps clone).
REPO_DIR="/opt/homelab-repo/nodes/dns-102/services/adguard"
ENV_FILE="/srv/adguard/adguard.env"
TEMPLATE_FILE="${REPO_DIR}/AdGuardHome.template.yaml"
LIVE_FILE="/srv/adguard/AdGuardHome.yaml"

# 1. Check if the template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "❌ Error: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# 2. Check if env exists and source it
if [[ -f "$ENV_FILE" ]]; then
    echo "🔒 Sourcing secrets from $ENV_FILE"
    # shellcheck source=/dev/null
    source "$ENV_FILE"
else
    echo "❌ Error: No env file found at $ENV_FILE"
    echo "  sudo mkdir -p /srv/adguard"
    echo "  sudo cp $REPO_DIR/adguard.env.example /srv/adguard/adguard.env"
    echo "  sudo chmod 600 /srv/adguard/adguard.env"
    echo "Please set ADGUARD_PASSWORD_HASH, DOMAIN_NAME, CADDY_NODE_IP, HOMELAB_NODE_IP"
    exit 1
fi

# 3. Ensure required vars are provided
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

# 4. Replace placeholders and write to the live location.
# awk avoids delimiter collisions (bcrypt uses $, / and .)
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

# 5. Permissions (service user adguard needs to read/rewrite config)
chmod 644 "$LIVE_FILE"
chown adguard:adguard "$LIVE_FILE" 2>/dev/null || true

echo "🔄 Restarting AdGuardHome service..."
systemctl restart AdGuardHome

echo "✅ Deployment complete!"
