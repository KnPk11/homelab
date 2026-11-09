# Pulse Infrastructure Monitoring Deployment

> **Location:** `nodes/pulse/services/pulse/deployment.md`  
> **Node:** `pulse` (`192.168.50.88`, Proxmox CT 107)

## 1. Overview & Architecture

Pulse is an infrastructure monitoring dashboard for Proxmox VE, tracking host/CT/VM resource utilisation, health metrics, and dispatching alerts (Telegram / Apprise).

* **Service Engine:** Native Go/systemd binary (`/opt/pulse/bin/pulse`).
* **Service Name:** `pulse.service`
* **Network & Port:** Listens internally on port `7655` (bound to localhost / LAN), accessed externally via Caddy reverse proxy on `reverse-proxy` (`192.168.50.101`).
* **PVE Connection:** Connects over TCP 8006 to Proxmox VE (`192.168.50.100`) using encrypted token authentication.

---

## 2. Secrets & Configuration

Runtime configuration lives under `/etc/pulse/` and `/srv/pulse/` (disposable clone must remain free of secrets):

| File | Purpose | Location |
| :--- | :--- | :--- |
| `.env` | Primary runtime variables & tokens | `/srv/pulse/.env` (template at `services/pulse/.env.example`) |
| `.encryption.key` | Symmetrical encryption key for `nodes.enc` | `/srv/pulse/.encryption.key` |
| `nodes.enc` | Encrypted Proxmox cluster nodes credentials | `/etc/pulse/nodes.enc` |

---

## 3. Deployment & Installation

### A. Upstream Installation (Run on Proxmox Host)
Pulse is initially provisioned via the upstream installer from the Proxmox host:
```bash
export PULSE_VERSION="v6.2.1" # Adjust to target release
curl -fsSLO "https://github.com/rcourtman/Pulse/releases/download/${PULSE_VERSION}/install.sh"
curl -fsSLO "https://github.com/rcourtman/Pulse/releases/download/${PULSE_VERSION}/install.sh.sshsig"
ssh-keygen -Y verify \
  -f <(printf '%s\n' 'pulse-installer namespaces="pulse-install" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMZd/DaH+BldzOkq1A8KVTcFk73nAyrE8aJOyf7i00jm pulse-installer') \
  -I pulse-installer -n pulse-install -s install.sh.sshsig < install.sh
bash install.sh --version "${PULSE_VERSION}" --disable-auto-updates
```

### B. Secrets Restoration & Service Restart (Inside `pulse` CT)
After a rebuild, restore `.env` and `.encryption.key` from the central secrets vault:
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

---

## 4. Connecting to Proxmox VE

Do not manually add PVE nodes via the UI with self-signed certificates. Instead:
1. Open Pulse UI → **Settings → Infrastructure → Install on a host** (type: **pve**).
2. Run the generated script **on the Proxmox host (`pve1`)** as root. This securely establishes the API token and writes the encrypted node record.

---

## 5. Verification & Health

```bash
# Verify systemd service status
systemctl status pulse

# Check listening daemon
ss -tulpn | grep 7655

# Tail live service logs
journalctl -u pulse -f
```
