# Deployment Strategy for homelab-95

## General Instructions
1. Clone or pull the `homelab_repo` repository to a central location on `homelab-95`.

## DBT Service Deployment
The DBT service consists of templated configuration files that need to be deployed to the host.

1. Navigate to the DBT service directory:
   ```bash
   cd nodes/homelab-95/services/dbt
   ```
2. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```
3. Edit the `.env` file and fill in all the required secrets (e.g., GCP_PROJECT_ID, POSTGRES_PASSWORD).
4. Run the deployment script to render the configuration templates and place them in the correct destination paths:
   ```bash
   ./deploy_app.sh
   ```
5. Deploy the docker-compose stack using Portainer, pointing to this repository, or run it manually using the rendered files.
