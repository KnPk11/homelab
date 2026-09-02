# Web-compromise watch

> [!NOTE]
> #Security #Telegram #Caddy #Docker

Detect **web-user grew a reverse-shell tool** (`🐚`) or **Docker published a new host port** (`🐳`). Not a SIEM.

Logic lives only here. `rollout.sh` installs on the HTTP-facing hosts (not the whole inventory).

| Host | Exec watch | Docker events |
| :--- | :--- | :--- |
| `reverse-proxy` | Caddy uid 999 shells / `nc` / python | no |
| `docker-services` | docker cgroup + `nc`/`ncat`/`socat` only | yes (privileged, host-net, new port) |
| `lab-vm` | `nc`/`ncat`/`socat` any uid | if Docker exists |
| `scratch-pc` | same | yes (Gitea and other compose) |

`lab-vm` / `scratch-pc` run Node/Python **as login user `k` (uid 1000)**. Watching `python`/`bash` there would ping on every app and every SSH session. Reverse-shell binaries only.

```bash
sudo /opt/homelab-repo/shared/observability/web-compromise-watch/rollout.sh
sudo /opt/homelab-repo/shared/observability/web-compromise-watch/rollout.sh --hosts lab-vm,scratch-pc
sudo /opt/homelab-repo/shared/observability/web-compromise-watch/deploy.sh   # this host
```
