# CrowdSec

> [!NOTE]
> **Tags:** #crowdsec #networking #security #distributed #mikrotik

This document covers the distributed CrowdSec architecture used to protect the network. It consists of a central "Brain" (LAPI), multiple "Sentinels" (Agents), and an "Edge Enforcer" (MikroTik).

## 1. The Architecture (Distributed Setup)

### Central Brain: Caddy LXC

- **Role**: Host the Local API (LAPI), store the database of bans, and manage bouncers.
- **Config**: `/etc/crowdsec/config.yaml` (must listen on LAN IP `[LAPI-IP]`).

### Sentinels: All other publicly exposed VMs

- **Role**: Parse local logs (SSH, Docker, AnyType, etc.) and forward alerts to the Brain.
- **Config**: `/etc/crowdsec/local_api_credentials.yaml` (points to Caddy LXC).

---

## 2. Configure the Central Brain

### Install CrowdSec

Installation:

```bash
# Add the repository:
curl -s https://install.crowdsec.net | sudo sh

# Install CrowdSec:
sudo apt-get install crowdsec
```

Add the bouncer and install relevant modules: 

```bash
# Add the firewall bouncer
sudo apt install crowdsec-firewall-bouncer-iptables

# Install the Caddy module
sudo cscli collections install crowdsecurity/caddy
```

Reload and check it's working:

```bash
sudo systemctl reload crowdsec
sudo cscli metrics
```

## 3. Log Parsing (Acquis Configuration)

Configure which logs CrowdSec should parse on the Caddy LXC, in `/etc/crowdsec/acquis.yaml`:

```yaml
filenames:
  - /var/log/auth.log
  - /var/log/syslog
  - /mnt/logs/caddy/json/*.log/*.log
labels:
  type: syslog
```

### Network Binding

To allow remote agents to connect, the LAPI must listen on the LAN:

```yaml
# In /etc/crowdsec/config.yaml
api:
  server:
    listen_uri: [LAPI-IP]:8080
```

### Registering Sentinels

On the Caddy container, add the machines:

```bash
sudo cscli machines add docker-host --password [SECRET]
sudo cscli machines add openclaw --password [SECRET]
```

---

## 4. Deploy Sentinels

On the agent machines, install CrowdSec but disable the local LAPI:

1. Edit `/etc/crowdsec/local_api_credentials.yaml`:

```yaml
url: http://[LAPI-IP]:8080
login: docker-host
password: [SECRET]
```

2. Restart: `sudo systemctl restart crowdsec`

---

## 5. MikroTik Edge Bouncer (The Precise Shield)

The bouncer runs on the Caddy LXC and pushes **"Local Only"** bans to the router. This keeps the MikroTik Address List clean and prevents UI lag.

**Config Location**: `/etc/crowdsec/bouncers/cs-routeros-bouncer.yaml`  
**Service Name**: `crowdsec-mikrotik-bouncer.service`

```yaml
crowdsec:
  api_url: "http://[LAPI-IP]:8080/"
```

---

## 6. Local Server Protection (The Global Shield)

While the MikroTik stays lean with local-only bans, the standard firewall bouncer on the **Caddy server** handles the massive **25,000+ Community Blocklist (CAPI)**.

**Config Location**: `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`  
**Service Name**: `crowdsec-firewall-bouncer.service`

```yaml
# This one pulls EVERYTHING and blocks it locally at the OS level
api_url: http://[LAPI-IP]:8080/
```

> [!NOTE]
> **DOCKER-USER Chain**: If running in Docker, configure the bouncer to also insert rules into the `DOCKER-USER` chain so bans apply to containers.
> Add this to `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`:
> ```yaml
> chains:
>   - INPUT
>   - DOCKER-USER
> ```

---

## 7. Fail2Ban Integration (The Bridge)

To push Fail2Ban bans to the MikroTik router, we feed them into CrowdSec.

1. **Create Action** (`/etc/fail2ban/action.d/crowdsec.conf`):

```ini
[Definition]
actionban = cscli decisions add --ip <ip> --duration 1h --reason 'Fail2Ban ban: <jail>'
actionunban = cscli decisions delete --ip <ip>
```

2. **Enable Globally** (`/etc/fail2ban/jail.local`):

```ini
[DEFAULT]
banaction_allports = crowdsec
```

---

## 8. Validation & Troubleshooting

### Check Connection Status

Verify all machines have a recent heartbeat:

```bash
sudo cscli machines list
```

### Verify CrowdSec is working & MikroTik Sync

Check if a test IP reaches the router:

1. Add ban: `sudo cscli decisions add --ip 1.2.3.4 --duration 5m`
2. Verify the ban: `sudo cscli decisions list`
3. In MikroTik: Check `IP > Firewall > Address Lists` for `CrowdSec_Blacklist`.
4. Remove ban: `sudo cscli decisions delete --ip 1.2.3.4`

> [!TIP]
> **Manual Verification**: Another option is to run a command that often gets triggered by crawlers: `curl -A "nikto" "https://filebrowser.example.com/"`, or temporarily stop Fail2Ban and try brute-forcing into a service with no rate limiting, such as File Browser.

### View Logs

- **Central Logs (Caddy LXC)**: `/mnt/logs/crowdsec/crowdsec.log`
- **MikroTik Bouncer**: `sudo journalctl -u crowdsec-mikrotik-bouncer -f`
- **Firewall Bouncer**: `sudo journalctl -u crowdsec-firewall-bouncer -f`

---

## 9. Allowlisting

Create allowlists for trusted IPs that should never be banned:

```bash
cscli allowlists create my-trusted-ips --description "My LAN"
sudo cscli allowlists add my-trusted-ips [TRUSTED-IP-1] [TRUSTED-IP-2] 10.x.x.x/24 -d "LAN and VPN"
sudo systemctl reload crowdsec
```

## Quick Reference

### Maintenance & Unbanning

> [!TIP]
> **Double-Layer Protection**: Because you have double-layer protection, you must unban through CrowdSec to clear both the MikroTik Edge and the local server firewalls.

```bash
# To view all active network-wide bans:
sudo cscli decisions list

# Manually unban an IP
sudo cscli decisions delete --ip <attacker_ip>
```
