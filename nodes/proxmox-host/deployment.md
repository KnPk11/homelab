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
| [proxmox_snapshot.sh](scripts/proxmox_snapshot.sh) | Scheduled snapshots of VMs/CTs (`S-YYYY-MM-DD`, retention ~14 days). Daily cron: `0 2 * * * /usr/local/bin/proxmox_snapshot.sh` |
| [firewall.sh](scripts/firewall.sh) | Applies Proxmox/cluster guest firewall definitions. Sources **`firewall.env`** from the same directory on the host (create from [firewall.env.example](scripts/firewall.env.example); do not commit real env). |
| [SSH doorbell](../../shared/observability/ssh-doorbell/deployment.md) | PAM `open_session` → Homelab Watch on successful SSH. |
| [thermal-safety-watchdog.sh](scripts/thermal-safety-watchdog.sh) | CPU package temp check every 30s via systemd timer (or cron). ≥92°C for 4 consecutive checks (~2m sustained) → Telegram alert + graceful guest/host shutdown. Reuses the doorbell's `/etc/ssh/telegram.env`. Test: `sudo WARN_TEMP=20 CRIT_TEMP=30 thermal-safety-watchdog.sh --dry-run` ×4. |

### Thermal watchdog (enable)

```bash
REPO=/opt/homelab-repo/nodes/proxmox-host
sudo ln -sfn "$REPO/scripts/thermal-safety-watchdog.sh" /usr/local/bin/thermal-safety-watchdog.sh

# Option A: systemd timer (runs every 30s)
sudo tee /etc/systemd/system/thermal-watchdog.service >/dev/null <<'EOF'
[Unit]
Description=Thermal safety watchdog (single check)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/thermal-safety-watchdog.sh
EOF

sudo tee /etc/systemd/system/thermal-watchdog.timer >/dev/null <<'EOF'
[Unit]
Description=Run thermal safety watchdog every 30s

[Timer]
OnBootSec=2min
OnUnitActiveSec=30s
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now thermal-watchdog.timer
journalctl -t thermal-watchdog -f

# Option B: root cron (runs every minute)
# * * * * * /usr/local/bin/thermal-safety-watchdog.sh >/dev/null 2>&1
```

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
