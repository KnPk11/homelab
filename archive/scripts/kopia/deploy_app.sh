#!/bin/bash
set -e

TARGET_DIR=$(pwd)

echo "Deploying Kopia backup scripts..."

if [ -f ".env" ]; then
    echo "Found .env secrets file!"
    
    # Make all scripts executable
    chmod +x homelab_backup_kopia.sh
    chmod +x initialise_repository.sh
    
    echo "Secrets and permissions securely configured."
    echo ""
    echo "To run the scripts, ensure you source the environment variables first:"
    echo "  source .env"
    echo "  sudo ./homelab_backup_kopia.sh [data|srv|docker|maintenance]"
else
    echo "No .env file found locally."
    echo "Please copy .env.example to .env, populate it with your Kopia password and AWS keys, and rerun this script."
fi

echo "Deployment setup complete."
