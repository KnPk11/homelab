# Dozzle Deployment

1. Clone or pull the repository to a central location on the target node.
2. Navigate to the `nodes/homelab-95/services/dozzle` directory.
3. Copy the `.env.example` file:
   ```bash
   cp dozzle.env.example dozzle.env
   ```
4. Run the deployment script to render templates and copy files to `/srv/dozzle`:
   ```bash
   ./deploy_app.sh
   ```
5. The `docker-compose.yml` stack should be orchestrated and deployed via Portainer directly from this repository.
