# Gatus Setup

> [!NOTE]
> **Tags:** #gatus #networking #native

---

## Introduction

This document outlines the manual installation and configuration of Gatus to provide a high-availability status page and automatic failover for `home.example.com`.

---

## 1. Installation

Since standard binary downloads can sometimes be blocked, building from source ensures compatibility.

1. Install Go (if not present)

   ```bash
   sudo apt update && sudo apt install golang -y
   ```

2. Download Gatus Source

   ```bash
   mkdir -p /opt/gatus
   cd /tmp
   curl -L https://github.com/TwiN/gatus/archive/refs/tags/v5.35.0.tar.gz -o gatus.tar.gz
   tar -xzf gatus.tar.gz
   cd gatus-5.35.0
   ```

3. Build and Install

   ```bash
   go build -o gatus .
   cp gatus /opt/gatus/gatus
   chmod +x /opt/gatus/gatus
   ```

---

## 2. Configuration

Gatus is configured to run on port **8081** (since 8080 is used by CrowdSec):

`/opt/gatus/config.yaml`

```yaml
web:
  port: 8081

storage:
  type: sqlite
  path: /opt/gatus/data.db

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
    url: "http://[HOMELAB-IP]:9102"
    interval: 30s
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[STATUS] == 200"]

  - name: OpenClaw
    url: "http://[OPENCLAW-IP]:18789"
    interval: 30s
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[STATUS] == 200"]

  - name: OMV
    url: "icmp://[OMV-IP]"
    interval: 30s
    ui:
      hide-url: true
      hide-hostname: true
    conditions: ["[CONNECTED] == true"]
```

---

## 3. Systemd Service

Create the service to ensure Gatus starts on boot:

`/etc/systemd/system/gatus.service`

```ini
[Unit]
Description=Gatus Status Page
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/gatus
Environment=GATUS_CONFIG_PATH=/opt/gatus/config.yaml
ExecStart=/opt/gatus/gatus
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now gatus
```

---

## 4. Caddy Failover Configuration

Update the `home.example.com` block in `/srv/caddy/Caddyfile`:

```caddyfile
home.example.com {
    # ... other imports ...
    
    # Try Dashy first, failover to Gatus on localhost
    reverse_proxy [HOMELAB-IP]:9102 localhost:8081 {
        lb_policy first
        health_uri /
        health_interval 10s
        health_timeout 2s
    }
}

gatus.example.com {
    import common-headers
    import common-robots
    import access_policy_wan 100 30s
    import common-logging-plaintext gatus
    import common-logging gatus

    reverse_proxy localhost:8081
}
```

---

## 5. Maintenance Commands

* **View Logs**: `journalctl -u gatus -f`
* **Restart**: `systemctl restart gatus`
* **Reload Caddy**: `caddy reload --config /srv/caddy/Caddyfile`
