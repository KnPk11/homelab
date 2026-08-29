# Banned IP Monitoring App

> [!NOTE]
> #Fail2Ban #CrowdSec #Security #Docker #Native

## 1. Description

Simple Python web server which shows IPs banned by Fail2Ban and CrowdSec in a rolling 24-hour window. Bans are appended to a dedicated JSONL history file as they happen; the widget reads that file rather than live CrowdSec/Fail2Ban logs (those rotate and CrowdSec's CLI defaults to the 50 most recent alerts).

## 2. Installation

### Docker

The monitor can be run as a custom-built Docker image.

1.  **Build/Run**
    
    Ensure the host's `/var/log/` is mounted into the container.

2.  **Port**
    
    Defaults to `9002`.

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

## 3. Troubleshooting

> [!WARNING]
> **History looks truncated at ~50 bans**: CrowdSec `cscli alerts list` defaults to `--limit 50`. The monitor must ingest with `--limit 0` into `/srv/fail2ban-monitor/banned-history.jsonl`. If that file is missing or the service is down, the widget cannot reconstruct a full 24h window from the CLI alone.
>
> **CrowdSec/Fail2Ban logs empty after midnight**: `process_logs.sh` truncates `/var/log/fail2ban.log` and `/var/log/crowdsec.log` nightly. That is expected and is why the widget uses the JSONL history file instead of those logs.

## 4. Security

- **Isolation**: Best to keep separate from Caddy. Do not run these kinds of scripts inside dedicated containers as it increases the likelihood of compromise, especially for an important service and considering the simplicity of the custom app.
- **LAN Access**: Having the app only be reachable within LAN (by Dashy) would be even better.
  - Note: Neither methods work in the iframe and apparently the widget loads using client's IP when browsing Dashy, so they won't work without further configuration.
  - Potential improvement: Implement authentication.
- **Best Practices**: Using shell scripts to call other scripts within a container is not considered best practice.
