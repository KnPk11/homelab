# Tailscale Setup

> [!NOTE]
> #Tailscale #VPN #Networking #DockerCompose #Proxmox

## 1. Description

A mesh VPN based on WireGuard that simplifies secure remote access and networking.

Unlike manual WireGuard configs, Tailscale easily keeps local SMB shares accessible while the tunnel is active. You don't need to enable an exit node to access your LAN shares — **subnet routes** (or being on the same Tailnet as a machine that has the share) cover that use case.

Hardening, ACLs, and firewall notes: [security.md](security.md).

## 2. Installation (Native)

1. **Install Tailscale**

   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   ```

2. **Enable IP Forwarding** (required for **exit node** and **subnet routes**)

   IPv4 **and** IPv6:

   ```bash
   sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null <<'EOF'
   net.ipv4.ip_forward = 1
   net.ipv6.conf.all.forwarding = 1
   EOF
   sudo sysctl --system
   # or: sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
   ```

   Confirm:

   ```bash
   cat /proc/sys/net/ipv4/ip_forward          # expect 1
   cat /proc/sys/net/ipv6/conf/all/forwarding # expect 1
   ```

   If Tailscale health reports *“Subnet routing is enabled, but IP forwarding is disabled”*, this step was skipped or not persisted.

3. **Start and Advertise the Service**

   Prefer omitting empty flags. Examples for this lab’s LANs:

   ```bash
   # Exit node only (no LAN route advertisement)
   sudo tailscale up --advertise-exit-node

   # Exit node + advertise lab subnets (adjust to your networks)
   sudo tailscale up --advertise-exit-node \
     --advertise-routes=192.168.50.0/24,192.168.88.0/24
   ```

> [!TIP]
> **Subnet advertising**: multiple CIDRs are a comma-separated list with **no spaces** (or as accepted by your `tailscale` version).  
> Do **not** use `--advertise-routes=` with an empty value — omit the flag instead.

4. **Authorise Routes in the Admin Console** (required — advertising alone is not enough)

   Open [Machines](https://login.tailscale.com/admin/machines) → your device → **`...` → Edit route settings**:

   | Toggle / item | Purpose |
   |---------------|---------|
   | **Use as exit node** | Approve exit-node role |
   | **Subnet routes** (each advertised CIDR) | Approve LAN routes (e.g. `192.168.50.0/24`) |

   Until these are approved, other devices will not use the node as exit node or reach those subnets via Tailscale.

5. **Clients That Should Use Subnet Routes**

   On phones/laptops that need to reach advertised LANs through this node:

   ```bash
   # Linux client
   sudo tailscale set --accept-routes=true
   ```

   On mobile/desktop apps: enable **Accept routes** / **Use subnet routes** (wording varies) for that network profile. Exit-node use is selected separately (“Exit node” → this machine).

6. **UDP GRO Forwarding** (optional performance tweak)

> [!NOTE]
> If you see a warning regarding suboptimal UDP GRO forwarding:

   ```bash
   sudo ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
   ```

   Persist after reboot (`sudo crontab -e`):

   ```bash
   @reboot /usr/sbin/ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
   ```

   On LXCs this may be a no-op or need the real interface name; safe to skip if `ethtool` fails.

7. **Disable Key Expiry** (stable servers)

   1. [Admin Console → Machines](https://login.tailscale.com/admin/machines)
   2. Device → `...` → **Disable key expiry**

### Example Bring-up on `vpns`

```bash
# Inside CT 108 (after install + sysctl)
sudo tailscale up --advertise-exit-node \
  --advertise-routes=192.168.50.0/24,192.168.88.0/24
# Then approve exit node + routes in Admin Console
```

## 3. Verification

### Mesh / Exit Node

```bash
tailscale status
tailscale netcheck          # DERP / direct UDP visibility
# From a client using this exit node: browse or curl ifconfig.me
```

### Subnet Routes

From a remote client with **accept routes** enabled, ping a LAN IP that is **not** the Tailscale node itself (e.g. `192.168.50.100` for pve1), after routes are **approved** in the admin console.

## 4. Troubleshooting

### DNS fight on Debian (resolv.conf conflict)

> [!WARNING]
> On Debian hosts, Tailscale's MagicDNS and NetworkManager can fight over `/etc/resolv.conf`. This causes DNS resolution to stall entirely — breaking git pulls, Docker image pulls, apt updates, and all outbound connectivity.

**Symptoms:** Intermittent DNS failures, services unable to resolve hostnames.

**Root Cause:** Debian doesn't ship with a DNS arbiter (like `systemd-resolved`). Both Tailscale and NetworkManager aggressively overwrite `/etc/resolv.conf`, and when one detects its config has been "trampled", DNS stalls during the tug-of-war.

**Fix:** Unless MagicDNS for Tailnet name resolution is needed, disable Tailscale DNS:

```bash
tailscale set --accept-dns=false
```

This hands DNS entirely back to NetworkManager → AdGuard, while Tailscale VPN tunnelling continues to work normally. The change persists across reboots.

> [!NOTE]
> If MagicDNS is needed in the future (e.g., to resolve `*.ts.net` hostnames), the alternative fix is to install a DNS arbiter: `apt-get install resolvconf`.

### Android app updates

> [!NOTE]
> **Android Update Indicator**: A red exclamation mark next to the account in the Android app may indicate a repository update that the Google Play Store has not yet received. This can generally be ignored.
