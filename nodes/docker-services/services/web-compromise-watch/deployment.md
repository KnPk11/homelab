# Web-compromise watch — docker-services

> [!NOTE]
> #Security #Telegram #Docker

Two doorbells, no auditd:

1. **`docker events`** — privileged, `network=host`, or a **new** published host port vs `/var/lib/web-compromise-watch/ports.baseline`.
2. **`/proc` exec watch** — processes in a docker cgroup whose comm is `nc`/`ncat`/`netcat`/`socat` only. Host uid 1000 is a login user; Nextcloud cron uses `sh`/`python` — those are not watched.

```bash
# /srv/homelab-watch/telegram.env must exist
sudo /opt/homelab-repo/nodes/docker-services/services/web-compromise-watch/deploy.sh
```

After you *mean* to publish a new port, refresh the baseline or the next start will ping Telegram.
