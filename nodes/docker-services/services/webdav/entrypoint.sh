#!/bin/sh
# =============================================================================
# entrypoint.sh
# Version: 1.2
# Date: 2026-08-11
#
# Container entrypoint: set WebDAV credentials from Docker secrets,
# map WEBDAV_DOMAIN to Apache SERVER_NAME, then exec upstream entrypoint.
#
# Usage:
#   Invoked by the container runtime (not run manually on the host).
# =============================================================================
set -e

# Load credentials from secret
export APP_USER_NAME=K
export APP_USER_PASSWD="$(cat /run/secrets/webdav_password)"

# Set Apache SERVER_NAME from WEBDAV_DOMAIN.
# If WEBDAV_DOMAIN is unset or SOPS-encrypted, fall back to localhost to prevent container crash loops.
case "${WEBDAV_DOMAIN:-${SERVER_NAME:-}}" in
  ""|ENC\[*)
    echo "webdav entrypoint: WARNING: WEBDAV_DOMAIN missing or SOPS-encrypted; falling back to localhost" >&2
    export SERVER_NAME="localhost"
    ;;
  *)
    export SERVER_NAME="${WEBDAV_DOMAIN:-$SERVER_NAME}"
    ;;
esac

exec "$WEBDAV_SOURCE_DIR/entrypoint.sh"