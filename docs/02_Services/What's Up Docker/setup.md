# What's Up Docker Setup

> [!NOTE]
> **Tags:** #WhatsUpDocker #Docker #Updates #Monitoring #Maintenance #DockerCompose

## 1. Description

**What's Up Docker (WUD)** is a self-hosted tool that monitors your Docker containers and notifies you when new images are available in the registries.

## 2. Setup

1. Add the Docker Compose stack to Portainer and start it.
2. Ensure the Docker socket is mounted as read-only to allow WUD to monitor local containers.
   
   ```yaml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock:ro
   ```

## 3. Configuration

### Telegram Notifications

Utilise environment variables to configure Telegram triggers for update alerts.

```yaml
environment:
  - WUD_TRIGGER_TELEGRAM_MYTELEGRAM_BOTTOKEN=[SECRET]
  - WUD_TRIGGER_TELEGRAM_MYTELEGRAM_CHATID=[SECRET]
```

### Local Watcher

By default, WUD periodically checks for updates. You can customise the check frequency using a cron expression:

```yaml
environment:
  - WUD_WATCHER_LOCAL_CRON=0 * * * * # Checks every hour
```
