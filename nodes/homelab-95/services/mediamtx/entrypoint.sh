#!/bin/sh
set -e

# Read secrets from mounted file
export MTX_PATHDEFAULTS_PUBLISHPASS=$(cat /run/secrets/mediamtx_password.secret)
export MTX_PATHDEFAULTS_PUBLISHUSER=kon

# Optional: debug
echo "Starting MediaMTX with password from file..."

# Execute original entrypoint (pass all args)
exec /mediamtx "$@"
