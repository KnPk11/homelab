# Homelab-95 Scripts Deployment

## Firewall (UFW)

Host-local security scripts live under `/opt/scripts/Security/`. The GitOps clone only holds the tracked `ufw.sh` and `ufw.env.example`.

| Path | Role |
| :--- | :--- |
| `.../scripts/ufw.sh` | Tracked script (in GitOps clone) |
| `.../scripts/ufw.env.example` | Template only |
| `/opt/scripts/Security/ufw.sh` | Symlink → tracked script |
| `/opt/scripts/Security/ufw.env` | Network layout (not in clone) |
| `/usr/local/bin/firewall` | Optional CLI symlink → `/opt/scripts/Security/ufw.sh` |

1. Create the env file:
   ```bash
   sudo mkdir -p /opt/scripts/Security
   sudo cp /opt/homelab-repo/nodes/docker-services/scripts/ufw.env.example /opt/scripts/Security/ufw.env
   sudo chmod 600 /opt/scripts/Security/ufw.env
   sudo nano /opt/scripts/Security/ufw.env
   ```

2. Symlink the tracked script into `/opt/scripts/Security/`, then a short CLI name:
   ```bash
   sudo ln -sfn /opt/homelab-repo/nodes/docker-services/scripts/ufw.sh /opt/scripts/Security/ufw.sh
   sudo chmod +x /opt/homelab-repo/nodes/docker-services/scripts/ufw.sh
   sudo ln -sfn /opt/scripts/Security/ufw.sh /usr/local/bin/firewall
   ```

3. Apply the rules:
   ```bash
   sudo firewall
   # or: sudo /opt/scripts/Security/ufw.sh
   ```

## Kopia backups

See [kopia/deployment.md](kopia/deployment.md) — scripts under `scripts/kopia/`, secrets under `/opt/scripts/Backups/Kopia/config/`.
