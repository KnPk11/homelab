# vpns: Master Bootstrap Guide

> **Hostname:** `vpns` | **IP:** `192.168.50.87` | **Proxmox:** CT 108 | **Type:** Proxmox LXC (Tailscale Subnet Router)

This node is the dedicated **remote access gateway and Tailscale subnet router**, advertising LAN subnets (`192.168.50.0/24` and `192.168.88.0/24`) without requiring port forwards on the WAN.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, synchronise the node from `ai-tools` (`sync-nodes <node>`), and re-run deployment steps.

**Secrets are not in Git.** The Tailscale machine cryptographic identity lives under `/var/lib/tailscale/tailscaled.state`. After a nuke-and-pave, restore that state file (or re-authenticate with a Tailscale auth key) before services will work.

---

## 1. System Bootstrap

* **Proxmox LXC Spec:** Review container allocation in **[Proxmox LXC Spec](../../docs/00_Infrastructure/proxmox/guests/vpns.md)** (CT 108, 1 core, 1 GB RAM, TUN passthrough).
* Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install base prerequisites and link this node to GitOps.

---

## 2. Kernel IP Forwarding

Subnet routing requires IP packet forwarding enabled in the Linux kernel:

```bash
sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sudo sysctl --system
```
*Verify:* `cat /proc/sys/net/ipv4/ip_forward` must return `1`.

---

## 3. Secrets & Persistent State

* **State File:** `/var/lib/tailscale/tailscaled.state` contains the node's cryptographic machine key. Restoring this file preserves the same Tailscale IP (`100.x.y.z`) across rebuilds.
* **Auth Key:** Reusable or ephemeral pre-authentication key from the [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys) if re-authorising fresh.

---

## 4. Deployment & Recovery Runbook

### A. Install & Enable Tailscale (If rebuilding bare LXC)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
```

### B. Authenticate & Advertise Subnet Routes
```bash
# If restoring identity from backup:
# sudo cp /path/to/vault/vpns/tailscaled.state /var/lib/tailscale/tailscaled.state
# sudo systemctl restart tailscaled

# Initial authentication & subnet advertisement:
sudo tailscale up \
  --advertise-routes=192.168.50.0/24,192.168.88.0/24 \
  --accept-routes \
  --ssh
```

### C. Approve Routes in Tailscale Console
In the Tailscale Admin Console → Machines → `vpns` → **Edit route settings** → Enable both advertised subnet routes.

---

## 5. Health Verification

```bash
# Check daemon status
systemctl status tailscaled

# Check tailnet connectivity and advertised subnet routes
tailscale status

# Test routing out to a LAN host
tailscale ping 192.168.50.100
```

---

## 6. Related Documentation & Services

* [Tailscale Architecture & Security Setup](../../docs/02_Services/tailscale/setup.md)
* [SSH Doorbell](../../shared/observability/ssh-doorbell/deployment.md) — PAM `sshd` login alert to Homelab Watch
