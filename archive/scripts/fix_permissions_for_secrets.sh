#!/bin/bash

# Sets appropriate permissions for ALL files in the "secrets" directory

EXPECTED_UID=1000
EXPECTED_GID=1000
GLANCES_PWD_PATH="/data/secrets/glances.pwd"
MEDIAMTX_PWD_PATH="/data/secrets/mediamtx_password"
NEXTCLOUD_HPB_PATH="/data/secrets/nextcloud_hpb_secrets.env"

echo "🔒 Validating and fixing permissions under /data/secrets and /data/certs..."

# 1. THE BLANKET: Set EVERYTHING to 600 (Secure by default)
# We use -exec to do it efficiently in one pass
find /data/secrets /data/certs -type f -exec chmod 600 {} +

# 2. THE EXCEPTIONS: Explicitly loosen the specific files
# We check if they exist first to avoid "No such file" errors
if [ -f "$GLANCES_PWD_PATH" ]; then
    echo "⚠️ Glances exception: Setting 644 on $GLANCES_PWD_PATH"
    chmod 644 "$GLANCES_PWD_PATH"
fi

if [ -f "$MEDIAMTX_PWD_PATH" ]; then
    echo "⚠️ MediaMTX exception: Setting 644 on $MEDIAMTX_PWD_PATH"
    chmod 644 "$MEDIAMTX_PWD_PATH"
fi

if [ -f "$NEXTCLOUD_HPB_PATH" ]; then
    echo "⚠️ Nextcloud HPB exception: Setting 644 on $NEXTCLOUD_HPB_PATH"
    chmod 644 "$NEXTCLOUD_HPB_PATH"
fi

# 3. OWNERSHIP: Fix user/group for everything
# (This part of your old script was fine, but we can simplify it)
find /data/secrets /data/certs \( ! -user "$EXPECTED_UID" -o ! -group "$EXPECTED_GID" \) \
    -exec chown "$EXPECTED_UID:$EXPECTED_GID" {} +
    
echo "✅ Done. Permissions and ownership corrected."