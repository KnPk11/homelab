# CrowdSec Fail2Ban Integration

> [!NOTE]
> **Tags:** #crowdsec #fail2ban #security #linux

## 1. Setup

Update and install a collection:

```bash
sudo cscli hub update
cscli scenarios install crowdsecurity/http-bad-user-agent
sudo systemctl restart crowdsec
```

Setting up the bouncer (the config is created at `/etc/crowdsec/bouncers/crowdsec-fail2ban-bouncer.yaml`):

```bash
sudo cscli bouncers add fail2ban-bouncer -k [SECRET]
```

Create a Custom Fail2Ban Action by adding the following to `/etc/fail2ban/action.d/crowdsec-check.conf`:

This configuration sends the detected IP to CrowdSec’s local API for analysis and retrieves a response indicating whether the IP is malicious.

```bash
[Definition]
actionstart =
actionstop =
actionban = curl -s -G "http://127.0.0.1:8080/v1/decisions?ip=<ip>" | jq -r '.[]?.value // empty'
actionunban =
```

Define a Fail2Ban Filter in `/etc/fail2ban/filter.d/crowdsec.conf`:

```bash
[Definition]
# failregex = ^<HOST> - .* "(GET|POST).*%%3Cscript.*" .*$
failregex = ^<HOST> - - .* "(GET|POST).*script.*".*$
ignoreregex =
```

Add the jail configuration to `/etc/fail2ban/jail.local`:

```bash
[crowdsec]
enabled = true
filter = crowdsec  
logpath = /srv/caddy/logs/*.log
port = http,https
backend = polling
bantime = 30m
findtime = 5m
maxretry = 1
action = crowdsec-check
```

Restart the services:

```bash
sudo systemctl restart fail2ban
sudo systemctl restart crowdsec
```

## 2. Testing

Check that the filter is active:

```bash
sudo fail2ban-client status crowdsec
```

Simulate a malicious request:

```bash
curl -A "malicious-bot" "http://example.com/%3Cscript%3Ealert(1)%3C/script%3E"
```
