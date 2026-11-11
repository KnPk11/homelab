# Paperclip Service Deployment

> **Node:** `lab-vm` (`192.168.50.91`) | **Port:** `3100` | **Service Kind:** systemd system unit (`/etc/systemd/system/paperclip.service`, run as `k`)

## 1. Overview

Paperclip is a self-hosted platform for orchestrating autonomous coding agents, operating on Node 24 with embedded PostgreSQL.

- **Runtime Path:** `/opt/paperclip/data/instances/default/` (owned by `k:k`)
- **System Unit:** [`paperclip.service`](paperclip.service) (`/etc/systemd/system/paperclip.service`)
- **Secrets Management:** In-place encryption using SOPS (`.env`, `secrets/*.secret`)
- **Architectural Reference:** [docs/02_Services/paperclip](../../../../docs/02_Services/paperclip/setup.md)

---

## 2. Prerequisites & Initial Installation

1. Verify Node 24 is available:
   ```bash
   node -v   # Expect v24.x
   ```

2. If Paperclip is not yet installed on the host, install the latest stable release globally:
   ```bash
   sudo npm install -g paperclipai@latest
   which paperclipai
   ```
   > [!TIP]
   > **Version Pinning:** Installing `@latest` ensures modern upstream agent compatibility. The verified working baseline release on this host is `paperclipai@2026.1023.0`. If a future `@latest` release introduces breaking upstream migrations, pin specifically to the verified release (`sudo npm install -g paperclipai@2026.1023.0`).

3. Verify SOPS and age private keys are configured on `lab-vm`:
   ```bash
   sops --version
   ```

---

## 3. Configuration & Secrets Decryption

1. Provision required runtime directories:
   ```bash
   sudo install -d -o k -g k /opt/paperclip /opt/paperclip/data /opt/paperclip/data/instances/default/secrets
   ```

2. Decrypt runtime environment and signing keys using SOPS:
   ```bash
   sops -d /opt/homelab-repo/nodes/lab-vm/services/paperclip/.env > /opt/paperclip/data/instances/default/.env
   sops -d /opt/homelab-repo/nodes/lab-vm/services/paperclip/secrets/master.key.secret | jq -r .data > /opt/paperclip/data/instances/default/secrets/master.key
   sops -d /opt/homelab-repo/nodes/lab-vm/services/paperclip/secrets/decision-signing.key.secret | jq -r .data > /opt/paperclip/data/instances/default/secrets/decision-signing.key
   ```

3. Secure file permissions:
   ```bash
   chmod 600 /opt/paperclip/data/instances/default/.env /opt/paperclip/data/instances/default/secrets/*
   chown -R k:k /opt/paperclip/data/instances/default
   ```

4. Install the tracked systemd service unit:
   ```bash
   sudo cp /opt/homelab-repo/nodes/lab-vm/services/paperclip/paperclip.service /etc/systemd/system/paperclip.service
   ```

5. Reload systemd and start the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now paperclip
   ```

---

## 4. Health Verification

Verify service status and API health endpoint:

```bash
# Check systemd status
sudo systemctl status paperclip

# Query health endpoint
curl -s http://127.0.0.1:3100/api/health
```
