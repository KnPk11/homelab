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

Under **Settings** → **DNS settings** → **Upstream DNS servers**, use:
```text
9.9.9.9
149.112.112.112
2620:fe::fe
2620:fe::9
```

### Client Visibility (MikroTik)

To see individual device names/IPs in AdGuard instead of just the router's IP:
1. Go to **IP** → **DHCP Server** → **Networks**.
2. **DNS Servers**: Change the router's own IP (`[ROUTER-IP]`) to the AdGuard IP (e.g., `[ADGUARD-IP]`) for all relevant networks.

> [!NOTE]
> **DNS Proxying**
> 
> If you set it under **IP** → **DNS**, the MikroTik acts as a proxy: clients ask the MikroTik, and the MikroTik asks AdGuard. This results in every request in AdGuard showing as coming from `[ROUTER-IP]`.

Add this rule to the top of the NAT firewall list:
```bash
/ip firewall nat add chain=dstnat dst-address=[ADGUARD-IP] protocol=udp dst-port=53 action=redirect to-ports=53 comment="AdGuard Failover Trap" disabled=yes
```

This rule will be enabled if the script cannot ping the AdGuard service, redirecting the traffic to the MikroTik router itself.

Go to **System** → **Scripts** → **New**
- **Name:** `CheckAdGuard`
- **Policy:** Ensure `read`, `write`, `test`, and `policy` are ticked.
- **Source:** Copy/Paste this code:

```bash
:local adguardIP  "[ADGUARD-IP]"
:local backupIP "9.9.9.9"
:local testDomain "google.com"

# --- DIAGNOSTIC RUN ---
:do {
    :log info "Script: Testing AdGuard connection to $adguardIP..."
    :resolve $testDomain server=$adguardIP
    
    # --- SUCCESS BRANCH (AdGuard is UP) ---
    :local currentDNS [/ip dns get servers]
    :if ($currentDNS != $adguardIP) do={
        /ip dns set servers=$adguardIP
        # Disable the "Trap" so clients talk to AdGuard directly
        /ip firewall nat disable [find comment="AdGuard Failover Trap"]
        /ip dns cache flush
        :log warning "Script: AdGuard RESTORED. Disabling NAT Trap."
    }
} on-error={
    :log error "Script: AdGuard FAILED to resolve $testDomain."
    
    # --- FAILURE BRANCH (AdGuard is DOWN) ---
    :local currentDNS [/ip dns get servers]
    :if ($currentDNS != $backupIP) do={
        /ip dns set servers=$backupIP
        # Enable the "Trap" to hijack traffic intended for AdGuard
        /ip firewall nat enable [find comment="AdGuard Failover Trap"]
        /ip dns cache flush
        :log warning "Script: AdGuard DOWN. Enabling NAT Trap to $backupIP."
    }
}
```

Go to **System** → **Scheduler** → **New**.
- **Name:** `DNS_Health_Check`.
- **Interval:** `00:01:00` (Every 1 minute).
- **Policy:** Ensure `read`, `write`, `test`, and `policy` are ticked.
- **On Event:** `CheckAdGuard` (This must match the script name exactly).

On the Asus router, the default settings (`Get the DNS IP from your ISP automatically`) should work. If not, try adding `[ROUTER-IP]` under WAN and LAN settings and restart the router.

> [!TIP]
> **Static DNS rules**: This may invalidate the static DNS rule for your domain which points at Caddy at `[CADDY-IP]`, because all traffic now goes directly through AdGuard, which pings upstream DNS. It is still useful to keep this static rule for failover.

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
/ip dhcp-server network set [find address="[GUEST-VLAN-SUBNET]/24"] dns-server=[ADGUARD-IP]
```

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
