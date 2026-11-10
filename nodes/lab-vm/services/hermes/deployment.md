# Hermes Service Deployment

> **Node:** `lab-vm` (`192.168.50.91`) | **Port:** `9119` (Dashboard) | **Service Kind:** systemd user units (`hermes-gateway`, `hermes-dashboard`)

## 1. Overview

Hermes is an AI agent management and dashboard system executed as user-level systemd services under user `k`.

- **Runtime Path:** `/home/k/.hermes/`
- **Config & Environment:** `/home/k/.hermes/config.yaml`, `/home/k/.hermes/.env`, `/home/k/.hermes/auth.json`
- **Reference Blueprint:** [`hermes.reference.yaml`](hermes.reference.yaml)
- **Architectural Reference:** [docs/02_Services/hermes](../../../../docs/02_Services/hermes/setup.md)

---

## 2. Prerequisites

1. Ensure user lingering is enabled:
   ```bash
   sudo loginctl enable-linger k
   ```
2. Verify Python virtual environment exists:
   ```bash
   /home/k/.hermes/hermes-agent/venv/bin/python --version
   ```

---

## 3. Configuration & Deployment

1. Restore configuration and credentials from the secrets vault (`secrets_vault/configs_and_secrets/lab-vm/home/k/.hermes/`) or seed from reference:
   ```bash
   mkdir -p /home/k/.hermes
   cp /opt/homelab-repo/nodes/lab-vm/services/hermes/hermes.reference.yaml /home/k/.hermes/config.yaml
   chmod 600 /home/k/.hermes/config.yaml /home/k/.hermes/.env
   ```

2. Symlink the tracked systemd user units:
   ```bash
   mkdir -p /home/k/.config/systemd/user
   ln -sfn /opt/homelab-repo/nodes/lab-vm/services/hermes/hermes-gateway.service /home/k/.config/systemd/user/hermes-gateway.service
   ln -sfn /opt/homelab-repo/nodes/lab-vm/services/hermes/hermes-dashboard.service /home/k/.config/systemd/user/hermes-dashboard.service
   ```

3. Reload and enable the services:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now hermes-gateway
   systemctl --user enable --now hermes-dashboard
   ```

---

## 4. Health Verification

Verify service status and dashboard connectivity:

```bash
# Check unit statuses
systemctl --user status hermes-gateway hermes-dashboard

# Test dashboard port connectivity
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9119
```
