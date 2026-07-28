# Gatus Setup

> [!NOTE]
> #Gatus #Networking #Native

## 1. Description

Gatus is a self-hosted status page and health checker: it probes HTTP, TCP, ICMP, and more, then shows uptime history for lab services.

## 2. Installation

Since standard binary downloads can sometimes be blocked, building from source ensures compatibility.

1. Install Go (if not present)

   ```bash
   sudo apt update && sudo apt install golang -y
   ```

2. Download Gatus Source

   ```bash
   mkdir -p /srv/gatus
   cd /tmp
   curl -L https://github.com/TwiN/gatus/archive/refs/tags/v5.35.0.tar.gz -o gatus.tar.gz
   tar -xzf gatus.tar.gz
   cd gatus-5.35.0
   ```

3. Build and Install

   ```bash
   go build -o gatus .
   cp gatus /srv/gatus/gatus
   chmod +x /srv/gatus/gatus
   ```

## 3. Configuration

Gatus is configured to run on port **8081** (since 8080 is used by CrowdSec):

`/srv/gatus/config.yaml`

```yaml
web:
  port: 8081

storage:
  type: sqlite
  path: /srv/gatus/data.db
  
ui:
  title: "Homelab Status"
  header: "System Status"
  
endpoints:
  - name: Reverse Proxy
    url: "tcp://127.0.0.1:80"
    interval: 1m
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[CONNECTED] == true"]

  - name: DNS
    url: "tcp://[DNS-IP]:53"
    interval: 30s
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[CONNECTED] == true"]

  - name: AI Tools
    url: "icmp://[AI-TOOLS-IP]"
    interval: 30s
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[CONNECTED] == true"]

  - name: Main Homelab
    url: "icmp://[HOMELAB-IP]"
    interval: 30s
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[CONNECTED] == true"]

  - name: OpenClaw
    url: "icmp://[OPENCLAW-IP]"
    interval: 30s
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[CONNECTED] == true"]

  - name: OMV
    url: "icmp://[OMV-IP]"
    interval: 30s
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[CONNECTED] == true"]
```

## 4. Systemd Service

Create the service to ensure Gatus starts on boot:

`/etc/systemd/system/gatus.service`

```ini
[Unit]
Description=Gatus Status Page
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/srv/gatus
Environment=GATUS_CONFIG_PATH=/srv/gatus/config.yaml
ExecStart=/srv/gatus/gatus
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now gatus
```

## 5. Caddy Configuration

Add a block for `gatus.example.com` in `/srv/caddy/Caddyfile` to expose Gatus securely within the LAN:

```caddyfile
gatus.example.com {
    import common-headers
    import common-robots
    import access_policy_lan
    import common-logging-plaintext gatus
    import common-logging gatus

    reverse_proxy localhost:8081
}
```

## 6. Maintenance Commands

* **View Logs**: `journalctl -u gatus -f`
* **Restart**: `systemctl restart gatus`
* **Reload Caddy**: `caddy reload --config /srv/caddy/Caddyfile`
