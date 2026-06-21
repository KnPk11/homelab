# Universal Node Bootstrap Guide

This guide outlines the standard boilerplate procedure required to bring any new or rebuilt node into the GitOps automation fold. This must be the very first step performed on a node before deploying any of its specific services.

## 1. Install Prerequisites

Ensure the machine has `git` installed:

```bash
# Debian/Ubuntu / Proxmox LXC
apt-get update && apt-get install -y git

# Alpine
apk add git
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
