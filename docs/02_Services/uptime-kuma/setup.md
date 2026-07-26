# Uptime Kuma Setup

> [!NOTE]
> **Tags:** #Uptime #Monitoring #DockerCompose

## 1. Description

A self-hosted monitoring tool that provides a status page and alerting for various services.

## 2. Installation

1. Add the Docker Compose stack to Portainer.
2. Set up a reverse-proxy with LAN-only access.
3. Visit the subdomain and create an admin account.
4. Select **Embedded MariaDB** as the database.
5. Go to **General** → **Primary Base URL** and set it to `https://status.homelab.local`.

## 3. Adding Monitors

### HTTP/HTTPS Monitors

Utilise **Monitor Type: HTTP(s)** for standard web services (e.g., `https://filebrowser.homelab.local`).

### Docker Container Monitoring

Mounting the Docker socket allows monitoring other services directly by container name.

```yaml
volumes:
  - uptime-kuma-data:/app/data
  - /var/run/docker.sock:/var/run/docker.sock:ro # Allows monitoring Docker containers
```

> [!WARNING]
> **Docker Socket Security**
> 
> Mounting the Docker socket (`/var/run/docker.sock`) provides the container with root-level access to the host. If container monitoring is not required, remove this line. Alternatively, utilise [Tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy) to limit API permissions.

### Public Status Page

The status page is accessible via `https://status.homelab.local/status/{slug-name}`.

## 4. Alerting Integration

### Telegram Notifications

#### Option 1: Group Chat (easier)

1. Navigate to **Settings → Notifications → Setup Notification** and select **Telegram**.
2. Provide your **Bot Token**: `[SECRET]`.
3. In your Telegram group, send: `/test @YourBotName`.
4. Click **Auto Get** next to Chat ID to retrieve the ID automatically.

#### Option 2: Private Channel

1. Add the bot as an administrator to your private channel.
2. Retrieve the Chat ID:
   - Post a message in the channel.
   - Forward it to [@getidsbot](https://t.me/getidsbot).
   - Copy the ID (e.g., `-100[SECRET]`).
3. In Uptime Kuma, enter the **Bot Token** and **Chat ID**.
4. Select **Test** to verify.

### Healthchecks.io Integration

This is useful for receiving alerts if the entire homelab loses connectivity. If your internet/power fails, Healthchecks.io notices the silence and triggers a Telegram alert.

#### Uptime Kuma to Healthchecks.io

Utilise a standard **HTTP(s)** monitor type:

1. **In Healthchecks.io**:
   - Create a Check.
   - Copy the **Ping URL** (e.g., `https://hc-ping.com/[SECRET]`).
2. **In Uptime Kuma**:
   - **Monitor Type**: HTTP(s).
   - **Friendly Name**: "Healthchecks Heartbeat".
   - **URL**: Paste the Ping URL.
   - **Heartbeat Interval**: 60 seconds.

> [!TIP]
> **Grace Period**
> 
> Set the Healthchecks.io **Grace Period** to at least **2 minutes** to prevent false alerts from transient network issues.

#### Healthchecks.io to Telegram

Connect Healthchecks.io directly to Telegram for redundant alerting.

1. **Add Bot as Administrator**:
   - In your private Telegram channel, go to **Settings** → **Administrators**.
   - Add `@HealthchecksBot` and grant permission to **Post Messages**.
2. **Trigger the Connection**:
   - Send `/start` in the private channel.
   - Follow the confirmation link provided by the bot.
   - Select your project and click **Connect Telegram**.

## 5. Additional Features

- **Maintenance Windows**: Schedule downtime for updates to suppress alert spam.
- **Push Monitors**: Allow services or scripts to "ping" Uptime Kuma, which is ideal for monitoring cron jobs.
