#!/bin/sh
# =============================================================================
# entrypoint.sh
# Version: 1.1
# Date: 2026-07-01
#
# Container entrypoint: set WebDAV credentials from Docker secrets, then exec upstream entrypoint.
#
# Usage:
#   Invoked by the container runtime (not run manually on the host).
# =============================================================================
set -e

export APP_USER_NAME=K
export APP_USER_PASSWD=$(cat /run/secrets/webdav_password)

exec "$WEBDAV_SOURCE_DIR/entrypoint.sh"