# Banned IP Monitoring App

> [!NOTE]
> **Tags:** #fail2ban #crowdsec #security #docker #native

## Description

Simple Python web server which parses logs to output IPs banned by Fail2Ban and CrowdSec in the past 24 hours.

## 1. Installation

### Docker

The monitor can be run as a custom-built Docker image.

1. **Build/Run**: Ensure the host's `/var/log/` is mounted into the container.
2. **Port**: Defaults to `9002`.

### Native

For lightweight environments like the Caddy LXC, the monitor can run as a native systemd service.

#### Installation

Copy the script to a persistent directory:

```bash
sudo mkdir -p /srv/fail2ban-monitor
sudo cp fail2ban_bans.py /srv/fail2ban-monitor/fail2ban_bans.py
sudo chmod +x /srv/fail2ban-monitor/fail2ban_bans.py
```

#### Service Configuration

Create the systemd service file at `/etc/systemd/system/fail2ban-monitor.service`:

```ini
[Unit]
Description=Fail2Ban and CrowdSec Monitor
After=network.target

[Service]
ExecStart=/usr/bin/python3 /srv/fail2ban-monitor/fail2ban_bans.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

#### Start & Enable

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fail2ban-monitor
```

## 2. Troubleshooting

> [!WARNING]
> **CrowdSec IP Parsing Failure**: If the app fails to return any IPs from CrowdSec, it might be due to the system locale causing the Python regex to fail on date parsing. Ensure logs are in the expected standard format.

## 3. Security

- **Isolation**: Best to keep separate from Caddy. Do not run these kinds of scripts inside dedicated containers as it increases the likelihood of compromise, especially for an important service and considering the simplicity of the custom app.
- **LAN Access**: Having the app only be reachable within LAN (by Dashy) would be even better.
  - Note: Neither methods work in the iframe and apparently the widget loads using client's IP when browsing Dashy, so they won't work without further configuration.
  - Potential improvement: Implement authentication.
- **Best Practices**: Using shell scripts to call other scripts within a container is not considered best practice.
