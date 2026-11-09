# Tailscale Subnet Router Deployment

> **Location:** `nodes/vpns/services/tailscale/deployment.md`  
> **Node:** `vpns` (`192.168.50.87`, Proxmox CT 108)

## 1. Overview & Architecture

This node acts as the central **Tailscale Subnet Router** for the homelab, enabling secure remote access into internal subnets (`192.168.50.0/24` and `192.168.88.0/24`) without exposing router WAN ports or requiring port forwards.

* **Daemon:** `tailscaled.service`
* **Subnet Routes Advertised:** `192.168.50.0/24`, `192.168.88.0/24`
* **Kernel Requirements:** Linux IPv4 and IPv6 forwarding enabled.

---

## 2. Secrets & State

* **Auth Key:** Reusable or ephemeral pre-authentication key generated from the [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys).
* **State File:** `/var/lib/tailscale/tailscaled.state` contains this node's cryptographic machine key. Restoring this file preserves the same Tailscale IP (`100.x.y.z`) across rebuilds.

---

## 3. Installation & Deployment

### A. Enable Kernel IP Forwarding
Subnet routing requires IP packet forwarding in the Linux kernel:
```bash
sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sudo sysctl --system
```
*Verify:* `cat /proc/sys/net/ipv4/ip_forward` must return `1`.

### B. Install & Enable Tailscale
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
```

### C. Authenticate & Advertise Subnet Routes
```bash
# If restoring identity from backup:
# sudo cp /path/to/vault/vpns/tailscaled.state /var/lib/tailscale/tailscaled.state
# sudo systemctl restart tailscaled

# Initial authentication & route advertisement:
sudo tailscale up \
  --advertise-routes=192.168.50.0/24,192.168.88.0/24 \
  --accept-routes \
  --ssh
```

### D. Approve Subnet Routes
In the Tailscale Admin Console → Machines → `vpns` → **Edit route settings** → Enable both advertised subnet routes.

---

## 4. Health Verification

```bash
# Check daemon status
systemctl status tailscaled

# Check tailnet connectivity and advertised routes
tailscale status

# Test routing out to a LAN host
tailscale ping 192.168.50.100
```
