# Universal Node Bootstrap Guide

This guide outlines the standard boilerplate procedure required to bring any new or rebuilt node into the GitOps automation fold. This must be the very first step performed on a node before deploying any of its specific services.

## 1. Install Prerequisites

Ensure the machine has `git` installed:

```bash
# Debian/Ubuntu / Proxmox LXC
apt-get update && apt-get install -y git rsync

# Alpine
apk add git rsync
```

## 2. Clone the Repository

Clone the public homelab repository into the standardized `/opt/homelab-repo` directory:

```bash
git clone https://github.com/KnPk11/homelab.git /opt/homelab-repo
```

## 3. Enable GitOps Automation (Cron)

We use a shared script (`auto_pull_repo.sh`) to ensure the node rigidly snaps to the master branch. 

To prevent all nodes from hitting GitHub or the network at the exact same second, **you must stagger the execution minutes**. Check the node's specific `deployment.md` playbook for its assigned minute offset.

1. Open the crontab editor:
   ```bash
   crontab -e
   ```
2. Add the following entry (replacing `XX` with the node's assigned minute):
   ```bash
   XX * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1
   ```

## 4. Proceed to Node-Specific Playbook

Once the node is bootstrapped and pulling changes autonomously, return to the node's specific `deployment.md` file to deploy its services.

## 5. Fleet-wide Homelab Watch

Rolled out from **`ai-tools`**. Do **not** copy these into each `nodes/*/deployment.md` — the host lists live with the scripts.

*   [SSH doorbell](../observability/ssh-doorbell/deployment.md) — PAM successful SSH on every Linux SSH host.
*   [Weekly sweep](../observability/weekly-sweep/deployment.md) — Sunday timer. Reboot flags on the Linux sweep hosts, CrowdSec on reverse-proxy, DSTNAT from ai-tools, planted-file presence where a local list exists.

```bash
# on ai-tools, God Mode unlocked
/opt/dev/homelab_repo/shared/observability/ssh-doorbell/rollout.sh
/opt/dev/homelab_repo/shared/observability/weekly-sweep/rollout.sh
```
