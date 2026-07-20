# AdGuard Home Setup & Configuration

> [!NOTE]
> **Tags:** #DNS #AdGuard #Docker #LXC #Monitoring #Security

## Overview

Primary DNS and Ad-blocking service for the network. This document covers two setup methods: Docker-based and Bare-Metal LXC.

---

## Option A: Docker Setup

This method runs AdGuard Home as a container, typically managed via Portainer.

### 1. Docker Compose

Add the docker compose to Portainer and start the stack.

### 2. Permissions

If you encounter permission issues:

```bash
sudo chown -R root:root /srv/adguard
sudo chmod -R 755 /srv/adguard
sudo chmod 644 /srv/adguard/conf/AdGuardHome.yaml
```

---

## Option B: Bare-Metal LXC Setup

This method runs AdGuard Home directly on a lightweight Debian LXC for better decoupling.

### 1. Installation

```bash
# Recommended location for services
mkdir -p /srv && cd /srv

# Install dependencies
apt-get update && apt-get install -y curl tar

# Download and install binary
curl -L https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz -o AdGuardHome.tar.gz
tar -xvzf AdGuardHome.tar.gz -C /srv/adguard --strip-components=1
./AdGuardHome/AdGuardHome -s install
rm AdGuardHome.tar.gz
```

### 2. Security Hardening (Non-Root Setup)

By default, AdGuard Home runs as `root`. To harden the installation:

```bash
# 1. Create a dedicated system user
useradd -r -s /usr/sbin/nologin adguard

# 2. Set ownership of the service directory
chown -R adguard:adguard /srv/adguard

# 3. Grant capability to bind to low ports (DNS 53, HTTP 80)
apt-get install -y libcap2-bin
setcap 'cap_net_bind_service=+ep' /srv/adguard/AdGuardHome
```

### 3. Service Management

Update `/etc/systemd/system/AdGuardHome.service` with these hardened settings:

```ini
[Service]
User=adguard
Group=adguard
WorkingDirectory=/srv/adguard
ExecStart=/srv/adguard/AdGuardHome -s run

# Security Sandboxing
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true
```

```bash
systemctl daemon-reload
systemctl restart AdGuardHome
systemctl status AdGuardHome
```

---

## General Configuration

### Web Interface

Navigate to `http://[ADGUARD-IP]:3000` to complete the setup.
- Set listening interface to `All`.
- Set the password.
- Add reverse-proxy rule.

> [!TIP]
> **Port assignment**
> 
> To avoid conflicts with Caddy when running on the same VM, change the web interface port from `80` to something else, such as `3000`.

### Upstream DNS Servers

Under **Settings** → **DNS settings** → **Upstream DNS servers**, use two **different providers** (diversity, not two Quad9 anycasts):

```text
1.1.1.1
9.9.9.9
```

`upstream_mode: load_balance` is fine. Bootstrap can use the same pair. These only matter while AdGuard itself is up; they are **not** a substitute for when **dns-102 is offline**.

### Client DNS via MikroTik DHCP (current)

Clients should query **AdGuard only** (so logs show real device IPs and filtering is not bypassed):

1. **IP** → **DHCP Server** → **Networks** (main LAN, homelab, guest — all of them).
2. **DNS Servers:**

```bash
/ip dhcp-server network
set [find comment=defconf] dns-server=[ADGUARD-IP]
set [find comment=homelab] dns-server=[ADGUARD-IP]
set [find comment=guest-vlan] dns-server=[ADGUARD-IP]
```

| Order | Server | Role |
|-------|--------|------|
| 1 | `[ADGUARD-IP]` | Filtering, rewrites, lab DNS — sole resolver advertised to clients |

Clients need a **new DHCP lease** (or renew) after this change.

> [!WARNING]
> Do **not** put `1.1.1.1` (or other public DNS) as a DHCP secondary. Many clients query both resolvers and **bypass AdGuard** even while dns-102 is healthy.

#### Router-side failover when AdGuard is down

When DHCP only advertises AdGuard, a dead dns-102 would otherwise break name resolution house-wide. The MikroTik health path restores browsing **without** dual DHCP DNS:

| Piece | Role |
|-------|------|
| Script **`CheckAdGuard`** | Every run: `:resolve google.com server=[ADGUARD-IP]` |
| Scheduler **`DNS_Health_Check`** | Interval **1m**, on-event `CheckAdGuard` (**enabled**) |
| NAT **AdGuard Failover Trap** (UDP + TCP) | `dstnat` redirect `[ADGUARD-IP]:53` → router DNS; **disabled** while healthy |
| Router **IP → DNS** | Servers = `[ADGUARD-IP]` when healthy; `9.9.9.9` when failed |
| **Allow remote requests** | **yes** so redirected client queries can be answered during failover |

On failure: set router DNS to `9.9.9.9`, **enable** traps, flush cache.  
On recovery: set router DNS back to `[ADGUARD-IP]`, **disable** traps, flush cache.

Clients keep using `[ADGUARD-IP]` from DHCP; while the trap is on, those packets are answered by the MikroTik (via public upstream). **Filtering is off during failover** — acceptable trade for outage resilience.

Full script source: [Appendix A](#appendix-a-mikrotik-adguard-health-script).

> [!NOTE]
> **DNS proxying**
>
> If DHCP pointed at the **router** and only **IP → DNS** listed AdGuard, AdGuard would show only `[ROUTER-IP]`. Prefer DHCP → AdGuard as above for normal operation.

### Asus AP Mode

On the Asus router (when running in AP mode off the MikroTik), the default settings (`Get the DNS IP from your ISP automatically`) should work. If not, try adding `[ROUTER-IP]` under WAN and LAN settings and restart the router.

> [!NOTE]
> **ASUS Merlin**: If the Asus router handles its own DHCP and uses the Merlin firmware, turn off "Advertise router's IP in addition to user-specified DNS".

### AdGuard Home DNS "Punch-Hole"

To allow isolated subnets (like the Guest VLAN) to utilise the internal AdGuard DNS server (`[ADGUARD-IP]`) without breaking network isolation, a "punch-hole" configuration was implemented.

**1. Address List Definition**

```bash
/ip firewall address-list add address=[ADGUARD-IP] list=DNS-Servers comment="AdGuard Home"
```

**2. Firewall Punch-Hole Rules**

These rules must be placed **before** the global isolation rule to allow DNS traffic to pass through the forward chain.

```bash
/ip firewall filter add chain=forward action=accept protocol=udp \
    dst-address-list=DNS-Servers dst-port=53 \
    comment="Allow all internal DNS queries to AdGuard (UDP)"

/ip firewall filter add chain=forward action=accept protocol=tcp \
    dst-address-list=DNS-Servers dst-port=53 \
    comment="Allow all internal DNS queries to AdGuard (TCP)"
```

**3. DHCP Configuration**

The DHCP server for the `guest-vlan` was updated to point directly to the AdGuard IP.

```bash
/ip dhcp-server network set [find address="[GUEST-VLAN-SUBNET]/24"] \
    dns-server=[ADGUARD-IP]
```

(Same AdGuard-only DHCP DNS as the other networks.)

### Reverse Proxy & Real IPs

If using a reverse proxy, add any of these to `AdGuardHome.yaml` to see real client IPs:

```yaml
trusted_proxies:
  - 127.0.0.0/8
  - [CADDY-IP]/32       # Caddy LXC IP
  - 172.16.0.0/12       # Covers all Docker networks
```

### IPv6 Reverse DNS Fix

If logs show Reverse DNS Lookup errors for IPv6, add `[ROUTER-IP]` under **Settings** → **DNS settings** → **Private reverse DNS servers**.

Also enable:
- Use private reverse DNS resolvers
- Enable reverse DNS resolution of upstream IP addresses

---

## Appendix A: MikroTik AdGuard health script

### Why it exists

When DHCP only advertises AdGuard, a downed dns-102 box means no name resolution for the whole house. The script probes AdGuard every minute; on failure it points the **router's** resolver at a public IP and enables a NAT redirect so queries aimed at `[ADGUARD-IP]:53` are answered by the MikroTik instead.

### Failover trap NAT (disabled by default; script toggles it)

```bash
/ip firewall nat
add chain=dstnat dst-address=[ADGUARD-IP] protocol=udp \
    dst-port=53 action=redirect to-ports=53 \
    comment="AdGuard Failover Trap" disabled=yes
add chain=dstnat dst-address=[ADGUARD-IP] protocol=tcp \
    dst-port=53 action=redirect to-ports=53 \
    comment="AdGuard Failover Trap TCP" disabled=yes
```

Also: **IP → DNS → Allow Remote Requests = yes** (so redirected queries can be answered).

### Script `CheckAdGuard`

**System** → **Scripts** → **New**

- **Name:** `CheckAdGuard`
- **Policy:** `read`, `write`, `test`, `policy`
- **Source:**

```bash
:local adguardIP  "[ADGUARD-IP]"
:local backupIP "9.9.9.9"
:local testDomain "google.com"

:do {
    # :log info "Script: Testing AdGuard connection to $adguardIP..."
    :resolve $testDomain server=$adguardIP

    :local currentDNS [/ip dns get servers]
    :if ($currentDNS != $adguardIP) do={
        /ip dns set servers=$adguardIP
        /ip firewall nat disable [find where comment~"AdGuard Failover Trap"]
        /ip dns cache flush
        :log warning "Script: AdGuard RESTORED. Disabling NAT Trap."
    }
} on-error={
    :log error "Script: AdGuard FAILED to resolve $testDomain."

    :local currentDNS [/ip dns get servers]
    :if ($currentDNS != $backupIP) do={
        /ip dns set servers=$backupIP
        /ip firewall nat enable [find where comment~"AdGuard Failover Trap"]
        /ip dns cache flush
        :log warning "Script: AdGuard DOWN. Enabling NAT Trap to $backupIP."
    }
}
```

### Scheduler `DNS_Health_Check`

**System** → **Scheduler** → **New**

- **Name:** `DNS_Health_Check`
- **Interval:** `00:01:00`
- **Policy:** `read`, `write`, `test`, `policy`
- **On Event:** `CheckAdGuard`
- **Disabled:** no (enabled)

To pause without deleting:

```bash
/system scheduler set [find name=DNS_Health_Check] disabled=yes
```
