# SSH doorbell (all SSH hosts)

> [!NOTE]
> #Security #Telegram #SSH #PAM

Successful `sshd` login → Homelab Watch. `session optional` on `/etc/pam.d/sshd` only.

**Where it belongs:** every inventory Linux box that has SSH, including `scratch-pc` (weakest workstation). Skip Windows. Do not put this in `common-session` (sudo would fire).

| Host | Why |
| :--- | :--- |
| `proxmox-host` | Hypervisor |
| `reverse-proxy` | Internet-facing LXC |
| `docker-services` | App VM |
| `nas` | Storage |
| `lab-vm` | OpenClaw |
| `ai-tools` | Admin / keys |
| `dns` | AdGuard |
| `pulse` | Infra monitor |
| `vpns` | VPN LXC |
| `pbs` | Backups |
| `k8s` | k3s |
| `scratch-pc` | Least-trusted workstation — still has SSH |

Logic lives only here. **Do not copy this into `nodes/`.** `rollout.sh` loops `DEFAULT_HOSTS` (the table above) and runs `deploy.sh` on each box — that creates `/usr/local/sbin/ssh-telegram-notify` → this directory in the clone. New machine: add it to `DEFAULT_HOSTS` in `rollout.sh`.

```bash
# All inventory Linux SSH hosts (from ai-tools, God Mode key loaded):
sudo /opt/homelab-repo/shared/observability/ssh-doorbell/rollout.sh

# Subset:
sudo /opt/homelab-repo/shared/observability/ssh-doorbell/rollout.sh --hosts scratch-pc,dns

# Single node (already pulled):
sudo /opt/homelab-repo/shared/observability/ssh-doorbell/deploy.sh
```

Telegram secret stays runtime (`/etc/ssh/telegram.env` or `/srv/homelab-watch/telegram.env`). The SOPS copy on `proxmox-host` is optional restore material, not a second script.
