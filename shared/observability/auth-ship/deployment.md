# Auth-ship (rsyslog → syslog LXC)

> [!NOTE]
> #Security #Syslog #Rsyslog

Not Grafana Alloy on every box. Each node already has rsyslog; this drop-in forwards `auth,authpriv.*` over TCP to the syslog LXC (`192.168.50.89:514`), which writes `/mnt/logs/auth/<host>/auth.log`. A 5-minute `logger` heartbeat makes “host silent” mean the **shipper died**, not “nobody logged in”. Do not install this on `syslog` itself (that box is the collector).

```bash
sudo /opt/homelab-repo/shared/observability/auth-ship/rollout.sh
```
