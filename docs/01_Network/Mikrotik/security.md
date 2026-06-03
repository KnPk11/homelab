> [!NOTE]
> **Tags:** #MikroTik #Security #Hardening #Firewall

# MikroTik Hardening & Security Guide

## Network Topology

### Scenario A: Logical Segregation (Single Router)
This relies on logical firewall rules to separate the homelab from the trusted LAN.
- **Risk:** High dependency on correct firewall configuration. A single misconfigured rule or bridge setting could bypass segregation.

### Scenario B: Physical Segregation (Two-Box Setup)
**Current Implementation:** The homelab is connected to the MikroTik. The trusted LAN is connected to a secondary router (Asus), which is in turn connected to the MikroTik.
- **Security Factor:** Even if MikroTik firewall rules are deleted, the trusted LAN remains protected as the secondary router blocks incoming traffic from its WAN port (where the MikroTik resides) by default.

---

## Tailscale Security
- **Isolation:** Traditional network segmentation is bypassed by Tailscale tunnels. Access control must be enforced via **Tailscale ACLs**.
- **Subnet Routing:** Should remain **disabled by default**. Only advertise subnets from individual hosts and require manual approval in the Tailscale admin panel.

---

## Basic Hardening

### Credentials
**System** → **Users** → **Users**:
1. Create a new account with a non-generic username and a secure password.
2. Log in with the new credentials.
3. Disable or delete the default `admin` account.

### HTTPS Management
Enable HTTPS for the admin interface and disable HTTP.

1. **Create the CA Certificate:**
```bash
/certificate add name=MyRouterCA common-name=MyRouterCA days-valid=3650 key-usage=key-cert-sign,crl-sign
/certificate sign MyRouterCA name=MyRouterCA
/certificate set MyRouterCA trusted=yes
```

2. **Create the Server Certificate:**
```bash
/certificate add name=WebServerCert common-name=[ROUTER-IP] days-valid=3650 key-usage=digital-signature,key-encipherment,tls-server subject-alt-name=IP:[ROUTER-IP]
```

3. **Sign the Server Certificate:**
```bash
/certificate sign WebServerCert ca=MyRouterCA
/certificate set WebServerCert trusted=yes
```

4. **Enable HTTPS Service:**
```bash
/ip service set www-ssl certificate=WebServerCert disabled=no port=8443
/ip service set www disabled=yes
```

### SSH Hardening
**IP** → **SSH**:
- Enable **Strong Crypto**.
- Change Host Key Type to **Ed25519**.

**Rate Limiting:**
```bash
/ip firewall filter add action=accept chain=input connection-state=new dst-limit=2/1m,5,src-address/1m40s dst-port=22 in-interface-list=LAN protocol=tcp comment="Accept rate-limited SSH from LAN"

/ip firewall filter add action=drop chain=input dst-port=22 protocol=tcp comment="Drop ALL other SSH"
```

> [!note] 
> 
> **Same-subnet limitation**
> 
> MikroTik firewall rules (forward chain) only apply to traffic **routed between subnets**.
> Devices on the same subnet communicate at layer 2 (switched), bypassing the router entirely.
> SSH rate-limiting must be enforced on each device individually, or via a hypervisor-level
> firewall (e.g. Proxmox) if the devices are VMs.

### Unused Services
**IP** → **Services**:
- Disable `api`, `api-ssl`, `telnet`, and `www`.
- **Tools** → **BTest Server**: Disable the service.
- **IP** → **UPnP**: Ensure it is disabled to prevent internal devices from opening ports automatically.
- **IP** → **Socks** / **Web Proxy**: Ensure these are disabled.

> [!tip]
> **Why disable proxy services?**
> These are legacy features that allow your router to act as a proxy server. If left enabled, your router becomes an "Open Proxy," allowing actors to route their traffic through your connection to hide their identity.

---

## Firewall Strategies

> [!warning]
> **Performance Implications:** Having a large number of firewall rules can impact the router's bandwidth throughput. Best practice is to keep the default "drop" rule at the bottom and add specific exceptions above it.

### Method 1: Interface Lists (Recommended)
Group logical interfaces (e.g., `vlan10`, `ether2`) into lists (e.g., `LAN_TRUSTED`, `LAN_UNTRUSTED`).

**Why this is superior:**
- **Anti-Spoofing:** Security is bound to the physical/virtual entry point. A malicious actor cannot bypass the firewall by simply assigning themselves a "Trusted" IP address.
- **Simplicity:** Survivors IP scheme changes without requiring rule rewrites.

#### Configuration Example:
```bash
# 1. Input Chain: Only allow management from specific interfaces
/ip firewall filter add chain=input action=accept in-interface-list=Trusted_LAN comment="Allow management from Trusted LAN"

# 2. Forward Chain: Isolate subnets while allowing internet access
/ip firewall filter add chain=forward action=drop in-interface-list=LAN_UNTRUSTED out-interface-list=!WAN comment="Drop untrusted to any local interface"

# 3. Block all other traffic
/ip firewall filter add chain=input action=drop comment="Implicit Deny all other input"
```

### Method 2: IP Address Lists
Used for granularity within the same subnet or when interface lists are too broad.

**Risk:** Vulnerable to IP spoofing if Layer 2 safeguards (DHCP Snooping) are absent, as it relies entirely on Layer 3 headers.

#### Configuration Example:
```bash
# 1. Forward Chain: Isolate Homelab using a "blanket drop" against RFC1918 subnets
/ip firewall filter add chain=forward action=drop src-address-list=Untrusted_Subnets dst-address-list=All_Private_Subnets comment="Force local isolation"

# 2. WAN Protection: Drop all from WAN not DSTNATed
/ip firewall filter add chain=forward action=drop connection-state=new connection-nat-state=!dstnat in-interface-list=WAN comment="Drop unsolicited WAN traffic"

# 3. Block all other traffic
/ip firewall filter add chain=input action=drop comment="Implicit Deny all other input"
```

### Resources
- [**MikroTik RouterOS 6.49.19 default firewall rules**](https://forum.mikrotik.com/t/buying-rb1100ahx4-dude-edition-questions-about-firewall/148996/4)

---

## Advanced Protection

### ICMP Rate Limiting
Prevents ping floods from consuming router resources.
```bash
/ip firewall filter set [find comment="defconf: accept ICMP"] limit=50/5s,2:packet
```

### MAC Server Lockdown
**Tools** → **MAC Server**:
Set MAC Telnet/WinBox/Ping servers to only allow the trusted LAN interface or disable them entirely.

> [!warning]
> MAC-based access bypasses IP firewall rules and is visible to anyone on the same L2 segment. Lockdown is essential to remove hidden Layer 2 management backdoors.

### Neighbour Discovery
**IP** → **Neighbors** → **Discovery Settings**:
Disable discovery on WAN, Guest, and IoT interfaces to prevent information leakage (MACs, IPs, Identity, Version).

### Bruteforce Protection
MikroTik can detect and blacklist IPs after multiple failed attempts. This is highly recommended for any service exposed to the LAN or WAN.

**Applicable Services:**
- **WinBox** (TCP/8291)
- **HTTPS Management** (TCP/443)
- **SSH**
- **Port-scan detection**
- **SYN flood protection**

**The Logic:**
1. 1st failed attempt → `stage1` address list.
2. 2nd failed attempt → `stage2` address list.
3. 3rd failed attempt → **Blacklisted** for 24 hours.

### Disable Unused Interfaces
A "Physical Security" best practice. Disabling unused ports (`etherX`) prevents unauthorized devices (e.g., from a guest or intruder) from gaining immediate network access by plugging in a cable.

### DNS Hardening
To prevent DNS Cache Poisoning (DNS Spoofing), shorten the maximum TTL:
```bash
/ip dns set cache-max-ttl=24h
```

---

## Verification & Testing

### WAN Access Test
Verify that management interfaces are NOT accessible from the public IP:
- `curl http://[PUBLIC-IP]:8443` (Should timeout).
- Check `IP > Firewall > Filter Rules` for the rule: `defconf: drop all not coming from LAN`.

### The "Escape" Test
Verify firewall isolation by attempting to move from an untrusted to a trusted zone.
- **How:** SSH into a **Homelab Server** (`[HOMELAB-IP]`) and attempt to ping a device on the **Trusted LAN** (`[TRUSTED-IP]`).
- **Success:** The ping MUST timeout or be refused. If it works, the "Drop" rule is likely in the wrong order.

### Port Scanning & Service Discovery
Use `nmap` from the homelab to verify pinhole rules:
```bash
nmap -Pn -p 80,443,445,139,1234 [ROUTER-IP-SECONDARY]
```
- **Expected:** Port `1234` is **open**, others are **filtered**.

Verify SMB isolation using the Samba client:
```bash
smbclient -L //[TRUSTED-IP] -N
```
- **Expected:** `Connection failed (Error NT_STATUS_IO_TIMEOUT)`.
