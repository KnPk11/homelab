# lab-vm: Master Bootstrap Guide

> **Hostname:** `lab-vm` | **IP:** `192.168.50.91` | **Proxmox:** VM 103 | **Type:** Proxmox VM (Development & AI Agents)

This node (`lab-vm`, `192.168.50.91`, Proxmox VM 103) is the primary application, developer, and AI agent workload host.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and restart the respective services.

If this machine ever suffers a catastrophic failure, follow the deployment guides below in order to restore it back to a working state.

---

## 1. System Bootstrap & User Linger

1. **Proxmox VM Provisioning:** Review resource allocation in **[Proxmox VM Spec](../../docs/00_Infrastructure/proxmox/guests/lab-vm.md)** (VM 103, 4 cores, 6 GB RAM).
2. **Universal Bootstrap:** Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install base prerequisites and link GitOps.
3. **Cron Offset:** Stagger `auto_pull_repo.sh` at minute **36**:
   ```bash
   (crontab -l 2>/dev/null; echo '36 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1') | sort -u | crontab -
   ```
4. **User Process Linger:** Required for user-level systemd daemons (`hermes`, `openclaw`) to persist across terminal logouts:
   ```bash
   sudo loginctl enable-linger k
   ```

---

## 2. Host Security & Firewall (UFW)

The host firewall is managed via the tracked script [`scripts/ufw.sh`](scripts/ufw.sh).

### 2.1 Firewall Installation & Deployment

1. Symlink the tracked firewall script into `/usr/local/bin/firewall`:
   ```bash
   sudo chmod +x /opt/homelab-repo/nodes/lab-vm/scripts/ufw.sh
   sudo ln -sfn /opt/homelab-repo/nodes/lab-vm/scripts/ufw.sh /usr/local/bin/firewall
   ```

2. Apply the firewall configuration:
   ```bash
   sudo firewall
   ```

### 2.2 Network Topology & Enforced Rules

- **Trusted Internal Zones:** Full access for Main LAN (`192.168.88.0/24`), Homelab LAN (`192.168.50.0/24`), and Docker internal subnet (`172.16.0.0/12`).
- **k3s Worker Node Rules:**
  - `8472/udp`: Flannel VXLAN overlay.
  - `10250/tcp`: Kubelet API (from `192.168.50.96` and homelab LAN).
  - `30000:32767/tcp`: Kubernetes NodePort services.
- **Restricted VPN Access:** SSH (`22/tcp`) from VPN subnets (`10.5.0.0/24`, `10.6.0.0/24`, `10.8.0.0/24`, `100.64.0.0/10`).

---

## 3. Workload & Service Routing

The services hosted on `lab-vm` are organised into dedicated service runbooks:

| Service | Port(s) | Service Kind / Unit | Runtime / Secret Path | Runbook |
| :--- | :--- | :--- | :--- | :--- |
| **Paperclip** | `3100` | systemd system unit (`paperclip.service`, user `k`) | `/opt/paperclip/data/instances/default/` (SOPS) | [services/paperclip/deployment.md](services/paperclip/deployment.md) |
| **Hermes Agent** | `9119` (Dashboard) | systemd user units (`hermes-gateway`, `hermes-dashboard`) | `/home/k/.hermes/` | [services/hermes/deployment.md](services/hermes/deployment.md) |
| **OpenClaw Gateway** | `18789` | systemd user unit (`openclaw-gateway.service`) | `/home/k/.openclaw/` | [services/openclaw/deployment.md](services/openclaw/deployment.md) |

### 3.1 Host Observability & Security Daemons

Shared fleet daemons deployed on `lab-vm` via central rollout scripts. Because they inherit credentials directly from `/etc/ssh/telegram.env` and utilise generic fallback profiles, they do not require local sub-service stub directories in Git:

| Service | Type | Scope on `lab-vm` | Runbook |
| :--- | :--- | :--- | :--- |
| **SSH Doorbell** | Observability | PAM `sshd` login alerts to Homelab Watch | [deployment.md](../../shared/observability/ssh-doorbell/deployment.md) |
| **Web-Compromise Watch** | Security | Process scan for reverse shells (`nc`, `socat`) on any UID | [deployment.md](../../shared/observability/web-compromise-watch/deployment.md) |

---

## 4. Disaster Recovery Order of Execution

In a complete disaster recovery scenario, execute the deployment in this exact sequence:

1. **System & Firewall:** Execute Universal Bootstrap, enable user linger for `k`, and deploy [`scripts/ufw.sh`](scripts/ufw.sh).
2. **Paperclip Service:** Follow [Paperclip Deployment](services/paperclip/deployment.md) to decrypt SOPS secrets and start the system service.
3. **Hermes Agent Service:** Follow [Hermes Deployment](services/hermes/deployment.md) to restore environment files and start user units.
4. **OpenClaw Service:** Follow [OpenClaw Deployment](services/openclaw/deployment.md) to link gateway unit and start the daemon.

---

## 5. Health Verification

Execute the following commands on `lab-vm` to verify host and service health:

```bash
# 1. Verify firewall rules
sudo ufw status verbose

# 2. Check Paperclip system service
sudo systemctl status paperclip

# 3. Check Hermes and OpenClaw user services
systemctl --user status hermes-gateway hermes-dashboard openclaw-gateway

# 4. Check local service HTTP endpoints
curl -s http://127.0.0.1:3100/api/health
curl -s -o /dev/null -w "Hermes Dashboard: %{http_code}\n" http://127.0.0.1:9119/
curl -s -o /dev/null -w "OpenClaw Gateway: %{http_code}\n" http://127.0.0.1:18789/
```
