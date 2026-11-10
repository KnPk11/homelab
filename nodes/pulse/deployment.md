# pulse: Master Bootstrap Guide

> **Hostname:** `pulse` | **IP:** `192.168.50.88` | **Proxmox:** CT 107 | **Type:** Proxmox LXC (Pulse Monitoring)

This node is the dedicated **infrastructure monitoring appliance** running the Pulse dashboard for Proxmox cluster health, VM/CT metrics, and Telegram alerts.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and re-run deployment steps.

**Secrets are not in Git.** Real `.env` and encryption keys live under `/srv/pulse/` and `/etc/pulse/`. After a nuke-and-pave, restore those from the secrets vault before services will work.

---

## 1. System Bootstrap

* Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install base prerequisites and link this node to GitOps.
* **Cron Offset:** Stagger `auto_pull_repo.sh` at minute **37**:
  ```bash
  (crontab -l 2>/dev/null; echo "37 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1") | sort -u | crontab -
  ```

---

## 2. Secrets & Configuration

| File | Purpose | Location |
| :--- | :--- | :--- |
| `.env` | Primary runtime variables & tokens | `/srv/pulse/.env` (template at `services/pulse/.env.example`) |
| `.encryption.key` | Symmetrical key for encrypted node records | `/srv/pulse/.encryption.key` |
| `nodes.enc` | Encrypted Proxmox cluster nodes credentials | `/etc/pulse/nodes.enc` |

---

## 3. Deployment & Recovery Runbook

### A. Upstream Installation (Run on Proxmox Host if rebuilding CT)
If rebuilding the container from bare Debian:
```bash
export PULSE_VERSION="v6.2.1" # Adjust to target release
curl -fsSLO "https://github.com/rcourtman/Pulse/releases/download/${PULSE_VERSION}/install.sh"
curl -fsSLO "https://github.com/rcourtman/Pulse/releases/download/${PULSE_VERSION}/install.sh.sshsig"
ssh-keygen -Y verify \
  -f <(printf '%s\n' 'pulse-installer namespaces="pulse-install" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMZd/DaH+BldzOkq1A8KVTcFk73nAyrE8aJOyf7i00jm pulse-installer') \
  -I pulse-installer -n pulse-install -s install.sh.sshsig < install.sh
bash install.sh --version "${PULSE_VERSION}" --disable-auto-updates
```

### B. Restore Secrets & Restart Daemon (Inside `pulse` CT)
```bash
sudo mkdir -p /srv/pulse /etc/pulse
sudo cp /path/to/vault/pulse/.env /srv/pulse/.env
sudo cp /path/to/vault/pulse/.encryption.key /srv/pulse/.encryption.key
sudo systemctl restart pulse
```

### C. Retrieve Initial Bootstrap Token (If UI is locked)
```bash
env PULSE_DATA_DIR=/etc/pulse /opt/pulse/bin/pulse bootstrap-token
```

### D. Connecting to Proxmox VE
Do not manually add PVE nodes via the UI with self-signed certificates. Instead:
1. Open Pulse UI → **Settings → Infrastructure → Install on a host** (type: **pve**).
2. Run the generated pairing command **on the Proxmox host (`pve1`)** as root to write the encrypted credentials.

---

## 4. Health Verification

```bash
# Verify systemd service status
systemctl status pulse

# Check listening daemon (port 7655)
ss -tulpn | grep 7655

# Tail live service logs
journalctl -u pulse -f
```

---

## 5. Related Documentation & Services

* [Pulse Architectural Setup & Feature Notes](../../docs/02_Services/pulse/setup.md)
* [SSH Doorbell](../../shared/observability/ssh-doorbell/deployment.md) — PAM `sshd` login alert to Homelab Watch
