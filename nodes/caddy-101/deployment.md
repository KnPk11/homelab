# Caddy-101 Deployment Notes

## Log Manager Script
The `process_logs.sh` script handles log rotation, archival, and retention.

### Deployment Strategy
1. **Clone the repository** to a central location on the node (e.g., `/opt/homelab-repo`).
2. **Create the Environment File**:
   Copy the example environment file and update it with local values if needed:
   ```bash
   cp /opt/homelab-repo/nodes/caddy-101/scripts/process_logs.env.example /opt/homelab-repo/nodes/caddy-101/scripts/process_logs.env
   ```
3. **Symlink to cron**:
   To run the script automatically (e.g., daily at midnight), create a symlink in the daily cron directory:
   ```bash
   sudo ln -s /opt/homelab-repo/nodes/caddy-101/scripts/process_logs.sh /etc/cron.daily/process_logs
   ```

> [!NOTE]
> The script dynamically discovers its `.env` file via `readlink`, so it can be safely symlinked anywhere on the system without breaking its configuration paths.
