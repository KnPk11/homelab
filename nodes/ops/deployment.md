# Ops-112 Master Bootstrap Guide

This node (`ops`, `192.168.50.112`, Proxmox CT 112) is the dedicated **unattended operations and background automation plane**. It isolates periodic network monitoring, alerting dispatchers, and router backup captures from interactive development workstations.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked config directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run service deployment steps.

**Secrets are not in Git.** Real `.env` files live under `/srv/<service>/` (e.g. `/srv/namecheap-ddns/ddns.env`, `/srv/homelab-watch/telegram.env`). After a nuke-and-pave, restore those from the secrets vault before services will work.

---

## 1. System Bootstrap & Scripts

* Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
* **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **39** to stagger network load.
  ```bash
  (crontab -l 2>/dev/null; echo "39 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1") | sort -u | crontab -
  ```
* **Universal VS Code Workspace:**
  To support the standard multi-folder [`home.code-workspace`](../../shared/vscode/home.code-workspace) with clean Git scanning:
  ```bash
  mkdir -p /opt/dev /data /srv /mnt
  ln -sfn /opt/homelab-repo /opt/dev/homelab_repo
  ln -sfn /opt/homelab-repo/shared/vscode/home.code-workspace /root/home.code-workspace
  git config --global --add safe.directory /opt/homelab-repo
  git config --global --add safe.directory /opt/dev/homelab_repo
  ```
  When connecting via VS Code Remote-SSH to `ops`, open `/root/home.code-workspace`.

---

## 2. Services on this node

| Service | Schedule | Description |
| :--- | :--- | :--- |
| [Namecheap Dynamic DNS](services/namecheap-ddns/deployment.md) | Every 5 mins (cron) | Synchronises residential WAN IPv4 with `ip.[DOMAIN]` |
| [Homelab Watch](services/homelab-watch/deployment.md) | On-demand / timers | Alert dispatch gateway to Telegram (`telegram.env`) |
| [Monthly Audit Reminder](services/monthly-audit-reminder/deployment.md) | Every Sunday 09:00 (timer) | Scheduled notification to trigger audit runs |
| WAN Saturation | Every minute (timer) | Monitors `pppoe-out1` saturation via router telemetry |
| MikroTik Config Capture | Every 3 hours (cron) | Pulls config exports via dedicated `svc_backup` key |
