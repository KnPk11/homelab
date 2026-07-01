#!/bin/sh
set -e

export APP_USER_NAME=K
export APP_USER_PASSWD=$(cat /run/secrets/webdav_password)

exec "$WEBDAV_SOURCE_DIR/entrypoint.sh"