# OpenClaw Service Deployment

> **Node:** `lab-vm` (`192.168.50.91`) | **Port:** `18789` | **Service Kind:** systemd user unit (`openclaw-gateway.service`)

## 1. Overview

OpenClaw is an agentic AI orchestration environment executed as a persistent user-level service under user `k`.

- **Runtime Path:** `/home/k/.openclaw/`
- **Config Target:** `/home/k/.openclaw/openclaw.json`
- **Reference Blueprint:** [`openclaw.reference.json`](openclaw.reference.json)
- **Architectural Reference:** [docs/02_Services/openclaw](../../../../docs/02_Services/openclaw/setup.md)

---

## 2. Prerequisites & Initial Installation

1. Ensure user lingering is enabled so user systemd services persist across logouts:
   ```bash
   sudo loginctl enable-linger k
   ```

2. If OpenClaw is not yet installed on the host, run the official installer as user `k`:
   ```bash
   curl -fsSL https://openclaw.ai/install.sh | bash
   ```

3. Verify Node.js 22 and OpenClaw CLI are installed:
   ```bash
   node -v
   which openclaw
   ```

---

## 3. Configuration & Deployment

1. Restore or configure `/home/k/.openclaw/openclaw.json` from the secrets vault or seed from the reference file:
   ```bash
   mkdir -p /home/k/.openclaw
   cp /opt/homelab-repo/nodes/lab-vm/services/openclaw/openclaw.reference.json /home/k/.openclaw/openclaw.json
   chmod 600 /home/k/.openclaw/openclaw.json
   ```

2. Symlink the tracked systemd user unit:
   ```bash
   mkdir -p /home/k/.config/systemd/user
   ln -sfn /opt/homelab-repo/nodes/lab-vm/services/openclaw/openclaw-gateway.service /home/k/.config/systemd/user/openclaw-gateway.service
   ```

3. Reload and enable the service:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now openclaw-gateway
   ```

---

## 4. Health Verification

Verify service status and local port listener:

```bash
# Check systemd user unit status
systemctl --user status openclaw-gateway

# Test gateway HTTP response
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18789/
```
