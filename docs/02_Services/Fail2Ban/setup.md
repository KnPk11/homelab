# Fail2Ban Setup

> [!NOTE]
> **Tags:** #fail2ban #networking #security #docker #native

Covers the installation of Fail2Ban to protect Caddy and the setup of the custom Python monitoring dashboard.

## 1. Installation

You can choose between a containerised or a native installation depending on your environment.

### Path A: Docker

Caddy requires a custom image with the `transform-encoder` module installed to provide a log format that Fail2Ban can accurately parse.

```yaml
services:
  fail2ban_monitor:
    image: fail2ban_monitor:latest
    volumes:
      - /var/log:/var/log:ro
      - /srv/fail2ban-monitor/fail2ban_bans.py:/usr/local/bin/fail2ban_bans.py:ro
    ports:
      - "9002:9002"
```

> [!NOTE]
> **Serving logs on the homepage widget**
> 
> Do not mount the log file directly like this:
> 
> ```yml
> - /var/log/fail2ban.log:/var/log/fail2ban.log:ro
> ```
> 
> Doing so leads to a stale file handle after the logs rotate. It is better to mount the entire directory containing the log.

Create the shared network:

```bash
docker network create caddy_shared
```

Initialise the configuration file:

```bash
sudo nano /etc/fail2ban/jail.local
```

Ensure Docker respects banned IPs by adding the following configuration:

```bash
sudo nano /etc/fail2ban/action.d/docker-user.conf
```

```ini
[Definition]
actionstart =
actionstop =
actioncheck = iptables -n -L DOCKER-USER | grep -q 'DROP'
actionban = iptables -I DOCKER-USER -s <ip> -j DROP
actionunban = iptables -D DOCKER-USER -s <ip> -j DROP
```

### Path B: Bare-metal

For standard Linux distributions:

```bash
sudo apt update && sudo apt install fail2ban -y
```

## 2. Configuration

### Log Permissions

Ensure the Fail2Ban service has the necessary permissions to read the Caddy logs:

```bash
sudo chown -R root:adm /mnt/logs/caddy
sudo chmod 755 /mnt/logs/caddy/plaintext/
sudo chmod 644 /mnt/logs/caddy/plaintext/*.log
```

### Filters

Create the `caddy-authcodes` regex rules to catch common exploit probes (e.g., 401: unauthorised, 403: forbidden):

```bash
sudo nano /etc/fail2ban/filter.d/caddy-authcodes.conf
```

```ini
[Definition]
# Unauthorised, failed auth, too many requests
failregex = ^<HOST> - - .+\s(401|403)\s.+
ignoreregex =
```

Create the `caddy-sensitivepaths` regex rule:

```bash
sudo nano /etc/fail2ban/filter.d/caddy-sensitivepaths.conf
```

```ini
[Definition]
# Generic endpoints
failregex = ^<HOST> - - .+(login|password|token).+
# Dashy - around 4x per page refresh
            ^<HOST> - - .+"(GET|POST) /conf.yml HTTP.*"
# Which service?
            ^<HOST> - - .+"GET \/get_stats\/.*" 200.+
# Privatebin - a few instances per page refresh
            ^<HOST> - - .+"(GET|POST) \/secretbin\/.*" 200.+
# Persistent requests even under throttling
            ^<HOST> - - .+".*" 429 0
ignoreregex = 
# File Browser - auth keyword part of fetching files
# ^<HOST> - - .+\/filebrowser\/api\/.*auth=
```

Verify the RegEx rules against your logs:

```bash
sudo fail2ban-regex /mnt/logs/caddy/plaintext/[SERVICE].log /etc/fail2ban/filter.d/caddy-authcodes.conf
```

## 3. Firewall & Bouncing

The method for applying bans depends on your host type.

### Docker or Full VM Hosts

On virtual machines with full kernel access, Fail2Ban can manage the local firewall directly.

```ini
# jail.local
banaction = docker-user
```

### LXC Containers

Standard LXC containers (such as [SERVICE-IP]) are restricted from modifying the host's firewall directly. To achieve blocking, Fail2Ban must delegate the ban to CrowdSec, which then pushes the instruction to the MikroTik Edge.

#### 1. Create the CrowdSec Action
Create the file `/etc/fail2ban/action.d/crowdsec.conf`:

```ini
[Definition]
# Pushes the ban to CrowdSec LAPI. 
# <bantime>s ensures the duration matches your jail config.
actionban = cscli decisions add --ip <ip> --duration <bantime>s --reason 'Fail2Ban: <name>'
actionunban = cscli decisions delete --ip <ip>
```

#### 2. Configure jail.local
Force Fail2Ban to utilise only the CrowdSec action, bypassing local iptables:

```ini
[DEFAULT]
# Disable local iptables (which fails in LXC)
banaction = crowdsec
banaction_allports = crowdsec
```

## 4. Testing & Verification

Follow these steps to ensure your Fail2Ban setup is functioning correctly.

### General Status
Check the status of the service to see the active jail list:

```bash
sudo fail2ban-client status
```

### RegEx Testing
Test your regex patterns against live or archived logs:

```bash
sudo fail2ban-regex /mnt/logs/caddy/plaintext/access.log /etc/fail2ban/filter.d/caddy-authcodes.conf
```

### Jail Monitoring
Inspect specific jails for failed attempts and current bans:

```bash
sudo fail2ban-client status caddy-authcodes
```

Monitor the primary Fail2Ban log for real-time ban activity:

```bash
sudo tail -f /var/log/fail2ban.log
```

### Firewall Verification
For Docker setups, verify that the `DOCKER-USER` chain contains the expected drop rules:

```bash
sudo iptables -L DOCKER-USER -n --line-numbers
```

### Log Analysis (Optional)
Identify the top IP addresses hitting your service logs:

```bash
awk '{print $1}' /srv/caddy/logs/plaintext/[SERVICE].log | sort | uniq -c | sort -nr | head
```

### MikroTik Bridge Verification
1. Trigger a manual ban in a test jail.
2. Confirm the IP appears in CrowdSec: `sudo cscli decisions list`.
3. Verify the IP has been added to the MikroTik Address List via the router's interface or CLI.
