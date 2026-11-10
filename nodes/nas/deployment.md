# nas: Master Bootstrap Guide

> **Hostname:** `nas` | **IP:** `192.168.50.90` | **Proxmox:** VM 101 | **Type:** Proxmox VM (OpenMediaVault)

This node (`nas`, `192.168.50.90`, Proxmox VM 101) is the primary **OpenMediaVault storage appliance** hosting ZFS/Btrfs datasets, SMB shares, and NFS mounts.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run service deployment steps.

**Secrets are not in Git.** Host-local firewall configurations (`firewall.env`) and storage credentials live outside the disposable GitOps clone. After a nuke-and-pave, restore those from the secrets vault before services will work.

---

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **34** to stagger network load:
    ```bash
    (crontab -l 2>/dev/null; echo "34 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1") | sort -u | crontab -
    ```

---

## 2. Services & Host Scripts

| Component | Protocol / Port | Role | Runbook |
| :--- | :--- | :--- | :--- |
| **OpenMediaVault** | 80/443 (Web), SMB, NFS | Central network attached storage | [OpenMediaVault Setup](../../docs/00_Infrastructure/openmediavault/setup.md) |
| **Host Firewall** | Security | Ingress/egress rules | [`scripts/firewall.sh`](scripts/firewall.sh) *(see below)* |
| **SSH Doorbell** | PAM `sshd` | Observability Telegram alert | [deployment.md](../../shared/observability/ssh-doorbell/deployment.md) |

### Firewall Deployment

1. On `nas`, decrypt the SOPS-encrypted firewall environment file (or restore from vault):
   ```bash
   sops -d /opt/homelab-repo/nodes/nas/scripts/firewall.env > /opt/homelab-repo/nodes/nas/scripts/firewall.env
   ```

2. Symlink the script to an execution path:
   ```bash
   ln -s /opt/homelab-repo/nodes/nas/scripts/firewall.sh /usr/local/bin/firewall
   chmod +x /opt/homelab-repo/nodes/nas/scripts/firewall.sh
   ```

3. Run the firewall script to apply the rules:
   ```bash
   sudo firewall
   ```

---

## 3. Related Documentation

*   [OpenMediaVault VM Provisioning & Storage Pass-through](../../docs/00_Infrastructure/openmediavault/proxmox-vm.md)
*   [OpenMediaVault Post-Install Configuration](../../docs/00_Infrastructure/openmediavault/setup.md)
