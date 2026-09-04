# Auth store (plaintext off-box logs)

> [!NOTE]
> #Security #Syslog #Rsyslog

rsyslog on this CT listens on TCP **514** and writes `/mnt/logs/auth/<host>/auth.log`. Nodes forward `auth,authpriv.*` with [auth-ship](../../../../shared/observability/auth-ship/deployment.md). Not Grafana Alloy, and not the Loki on `docker-services`.

```bash
sudo /opt/homelab-repo/nodes/syslog/services/auth-store/deploy.sh
```

Do not install auth-ship on **syslog** itself (that would loop).

Read logs:

```bash
auth-logs                  # last hour, all hosts
auth-logs scratch-pc
auth-logs --failed --since 24h
auth-logs --hosts
auth-logs -f reverse-proxy
# or
tail -F /mnt/logs/auth/scratch-pc/auth.log
```

`auth-watch.timer` (every 5 minutes) Telegrams `useradd`/`usermod` and a host whose `auth.log` has not grown for 15 minutes (heartbeat missing).
