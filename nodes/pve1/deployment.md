# pve1: Master Bootstrap Guide

> **Hostname:** `pve1` | **IP:** `192.168.50.100` | **Proxmox:** Host (Hypervisor) | **Type:** Bare-Metal (Lenovo Tiny)

This node is the **Proxmox VE hypervisor** (host for LXCs/VMs). Tracked scripts live in Git; host-local secrets (e.g. firewall env) stay off the disposable clone.

This node operates on a strict **Infrastructure as Intent** methodology. Do not treat one-off shell edits on the host as source of truth — update the repo, pull (or copy) scripts, then re-run them.

**Secrets are not in Git.** Prefer host-local files next to runtime (e.g. `firewall.env` beside the firewall script on the host, or under a dedicated path). After a nuke-and-pave, restore those from the secrets vault before re-applying firewall rules.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps where appropriate.

## 2. Services & Host Scripts

| Component | Type | Schedule / Trigger | Runbook |
| :--- | :--- | :--- | :--- |
| **Thermal Safety Watchdog** | Service / Timer | Every 30s (`systemd`) | [deployment.md](services/thermal-watchdog/deployment.md) |
| **Guest Snapshots** | Script | Daily at 02:00 (`cron`) | `0 2 * * * /usr/local/bin/proxmox-snapshot.sh` |
| **Cluster Firewall** | Script | On boot / network change | [`scripts/firewall.sh`](scripts/firewall.sh) *(see below)* |
| **HDD Spindown (`hd-idle`)** | Service (`systemd`) | 10 min idle (`sda` PBS HDD) | `/etc/default/hd-idle` (`-i 600 -c ata`) |
| **SSH Doorbell** | Observability | PAM `sshd` login | [deployment.md](../../shared/observability/ssh-doorbell/deployment.md) |
| **Intel TCO Hardware Watchdog** | Hardware | Autonomous PCH reset | [intel-hardware-watchdog.md](../../docs/00_Infrastructure/proxmox/intel-hardware-watchdog.md) |

> [!NOTE]
> **Host Settings Backup**
>
> Do not use third-party Proxmox `/etc` backup scripts. Host-local configs and PBS keys (`/etc/pve/priv/storage/`, `storage.cfg`, `jobs.cfg`, `firewall/*.fw`, guest `.conf` files, `50-pmx-nic*.link`, `fstab`, `interfaces`, `hd-idle`, `smartd.conf`, and root crontab) are backed up on-demand by [`scrape-configs-and-secrets.sh`](../ai-tools/services/configs-and-secrets-backup/scrape-configs-and-secrets.sh).

### Firewall secrets (host-local)

```bash
# On pve1, next to the script (or after symlink layout you prefer):
sudo cp /opt/homelab-repo/nodes/pve1/scripts/firewall.env.example \
  /opt/homelab-repo/nodes/pve1/scripts/firewall.env
sudo chmod 600 /opt/homelab-repo/nodes/pve1/scripts/firewall.env
# edit firewall.env — then:
sudo /opt/homelab-repo/nodes/pve1/scripts/firewall.sh
```

> Prefer moving `firewall.env` out of the clone later (same pattern as UFW on `.95`) if you want the GitOps tree fully free of host secrets.
