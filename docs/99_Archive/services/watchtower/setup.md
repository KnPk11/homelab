# Watchtower Setup

> [!NOTE]
> **Tags:** #Watchtower #Docker #Updates #Maintenance #DockerCompose

## 1. Description

A utility that automates the process of updating Docker containers by monitoring for new base image versions and gracefully restarting containers with the new image.

## 2. Installation

Add the docker compose stack to Portainer and start it.

## 3. Configuration

The following environment variables can be utilised to customise Watchtower's behaviour:

| Variable                   | Description                                                      | Default       |
| :------------------------- | :--------------------------------------------------------------- | :------------ |
| `WATCHTOWER_CLEANUP`       | Removes old images after a successful update to save disk space. | `false`       |
| `WATCHTOWER_POLL_INTERVAL` | Time in seconds between update checks.                           | `86400` (24h) |
| `WATCHTOWER_SCHEDULE`      | A Cron expression (6 fields) for precise scheduling.             | N/A           |
| `WATCHTOWER_MONITOR_ONLY`  | Checks for updates and notifies without restarting containers.   | `false`       |
| `WATCHTOWER_NOTIFICATIONS` | Notification type (e.g., `shoutrrr`, `slack`, `gotify`).         | N/A           |
| `TZ`                       | Sets the timezone for logs and scheduled updates.                | `UTC`         |

## 4. Advanced Usage

### Container-Specific Controls
You can exclude specific containers from updates by applying labels to them in their respective `docker-compose.yml` files.

```yaml
services:
  sensitive-app:
    image: sensitive-app:latest
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

