# Web-compromise watch — reverse-proxy

> [!NOTE]
> #Security #Telegram #Caddy

Caddy is uid `999`. This node is an LXC, so **auditd is not used**; a `/proc` poller watches that UID for shells and reverse-shell binaries.

```bash
# /srv/homelab-watch/telegram.env must exist (same bot as CrowdSec)
sudo /opt/homelab-repo/nodes/reverse-proxy/services/web-compromise-watch/deploy.sh
```

Test (should ping Homelab Alerts, then exit):

```bash
runuser -u caddy -- /bin/sh -c 'sleep 20'
```

Do not alert on Caddy HTTP 200s.
