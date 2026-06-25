#!/bin/sh
# This script reads a Docker secret and makes it available as an
# environment variable for ALL future shell sessions.

# Exit immediately if a command exits with a non-zero status.
set -e

SECRET_FILE="/run/secrets/postgres_password"
PROFILE_SCRIPT="/etc/profile.d/00-dbt-secrets.sh"

# Check if the secret file is mounted
if [ -f "$SECRET_FILE" ]; then
  # Read the secret's content
  SECRET_VALUE=$(tr -d '\n' < "$SECRET_FILE")
  
  # Create a shell script in /etc/profile.d/ to export the variable.
  # This ensures that any new shell session (like from 'docker exec')
  # will have this environment variable available.
  echo "export POSTGRES_PASSWORD='$SECRET_VALUE'" > "$PROFILE_SCRIPT"
fi

# Execute the command passed to the container (e.g., tail, bash, etc.)
exec "$@"