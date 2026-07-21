# Proxmox-100 Master Bootstrap Guide

This node is the **Proxmox VE hypervisor** (host for LXCs/VMs). Tracked scripts live in Git; host-local secrets (e.g. firewall env) stay off the disposable clone.

This node operates on a strict **Infrastructure as Intent** methodology. Do not treat one-off shell edits on the host as source of truth — update the repo, pull (or copy) scripts, then re-run them.

**Secrets are not in Git.** Prefer host-local files next to runtime (e.g. `firewall.env` beside the firewall script on the host, or under a dedicated path). After a nuke-and-pave, restore those from the secrets vault before re-applying firewall rules.

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap & Scripts

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install prerequisites and link this node to GitOps where appropriate.
*   **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **35** to stagger network load (between OMV `:34` and OpenClaw `:36`).
*   Deploy tracked scripts from the clone, for example:
    ```bash
    REPO=/opt/homelab-repo/nodes/proxmox-host/scripts
    sudo chmod +x "$REPO/proxmox_snapshot.sh" "$REPO/firewall.sh"
    # Optional stable names:
    # sudo ln -sfn "$REPO/proxmox_snapshot.sh" /usr/local/bin/proxmox_snapshot.sh
    ```

## 2. Host scripts

| Script | Role |
| :--- | :--- |
| [proxmox_snapshot.sh](scripts/proxmox_snapshot.sh) | Scheduled snapshots of VMs/CTs (`S-YYYY-MM-DD`, retention ~60 days). Example cron: `0 0 */2 * * /usr/local/bin/proxmox_snapshot.sh` |
| [firewall.sh](scripts/firewall.sh) | Applies Proxmox/cluster guest firewall definitions. Sources **`firewall.env`** from the same directory on the host (create from [firewall.env.example](scripts/firewall.env.example); do not commit real env). |

### Firewall secrets (host-local)

```bash
# On proxmox-host, next to the script (or after symlink layout you prefer):
sudo cp /opt/homelab-repo/nodes/proxmox-host/scripts/firewall.env.example \
  /opt/homelab-repo/nodes/proxmox-host/scripts/firewall.env
sudo chmod 600 /opt/homelab-repo/nodes/proxmox-host/scripts/firewall.env
# edit firewall.env — then:
sudo /opt/homelab-repo/nodes/proxmox-host/scripts/firewall.sh
```

> Prefer moving `firewall.env` out of the clone later (same pattern as UFW on `.95`) if you want the GitOps tree fully free of host secrets.
