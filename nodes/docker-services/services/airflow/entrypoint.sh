#!/bin/bash
set -e

# Load secrets
export AIRFLOW__API_AUTH__JWT_SECRET="$(cat /run/secrets/airflow_jwt_secret)"
export AIRFLOW__CORE__FERNET_KEY="$(cat /run/secrets/airflow_fernet_key)"

# Optional: log for debugging
echo "Secrets loaded. Starting Airflow..."

# Call original entrypoint
exec /entrypoint "$@"