> [!NOTE]
> **Tags:** #MikroTik #Security #Hardening #Firewall

# MikroTik Hardening & Security Guide

## Network Topology

### Scenario A: Logical Segregation (Single Router)

This relies on logical firewall rules to separate the homelab from the trusted LAN.

- **Risk**: High dependency on correct firewall configuration. A single misconfigured rule or bridge setting could bypass segregation.

### Scenario B: Physical Segregation (Two-Box Setup)

**Current Implementation**: The homelab is connected to the MikroTik. The trusted LAN is connected to a secondary router (Asus), which is in turn connected to the MikroTik.

- **Security Factor**: Even if MikroTik firewall rules are deleted, the trusted LAN remains protected as the secondary router blocks incoming traffic from its WAN port (where the MikroTik resides) by default.

---

## Tailscale Security

- **Isolation**: Traditional network segmentation is bypassed by Tailscale tunnels. Access control must be enforced via **Tailscale ACLs**.
- **Subnet Routing**: Should remain **disabled by default**. Only advertise subnets from individual hosts and require manual approval in the Tailscale admin panel.

---

## Basic Hardening

### Credentials

**System** → **Users** → **Users**:

1. Create a new account with a non-generic username and a secure password.
2. Log in with the new credentials.
3. Disable or delete the default `admin` account.

### HTTPS Management

Enable HTTPS for the admin interface and disable HTTP.

1. **Create the CA Certificate**
   
   ```bash
   /certificate add name=MyRouterCA common-name=MyRouterCA days-valid=3650 key-usage=key-cert-sign,crl-sign
   /certificate sign MyRouterCA name=MyRouterCA
   /certificate set MyRouterCA trusted=yes
   ```

2. **Create the Server Certificate**
   
   ```bash
   /certificate add name=WebServerCert common-name=[ROUTER-IP] days-valid=3650 key-usage=digital-signature,key-encipherment,tls-server subject-alt-name=IP:[ROUTER-IP]
   ```

3. **Sign the Server Certificate**
   
   ```bash
   /certificate sign WebServerCert ca=MyRouterCA
   /certificate set WebServerCert trusted=yes
   ```

4. **Enable HTTPS Service**
   
   ```bash
   /ip service set www-ssl certificate=WebServerCert disabled=no port=8443
   /ip service set www disabled=yes
   ```

### SSH Hardening

**IP** → **SSH**:
- Enable **Strong Crypto**.
- Host key type **Ed25519**.

**Input policy (current intent):**

| Source | SSH to router |
|--------|----------------|
| `LAN` list (main bridge + WireGuard) | Allow (rate-limited) |
| Port knock | Temporary allow |
| Agent host (e.g. ai-tools on Homelab) | Explicit allow |
| Everyone else | Drop |

```bash
/ip firewall filter
add action=accept chain=input connection-state=new dst-limit=2/1m,5,src-address/1m40s \
    dst-port=22 in-interface-list=LAN protocol=tcp comment="Accept rate-limited SSH from LAN"
add action=accept chain=input protocol=tcp src-address=[AGENT-CONTAINER-IP] dst-port=22 \
    comment="Agent SSH (ai-tools)"
add action=drop chain=input protocol=tcp dst-port=22 comment="Drop ALL other SSH" log=yes
```

Do **not** publish SSH with DSTNAT. Prefer VPN for admin; knock only as break-glass (`port-knocking.md`).

> [!NOTE]
> **Same-subnet limitation**
>
> **Forward** rules never see SSH between two hosts on the same L2 segment. Host keys / fail2ban / CrowdSec on the servers still matter.

### Management services (www-ssl / Winbox)

- **www-ssl** on **8443** (HTTPS WebFig) — leave `address=""` if port-knock Web UI must work from arbitrary public IPs after knock.
- **Winbox** — may restrict sources e.g. `192.168.88.0/24,10.5.0.0/24` (main LAN + WG); keep for LAN-cable recovery.
- Disable **www** (HTTP).

### Unused Services

**IP** → **Services**:

| Service | Guidance |
|---------|----------|
| `telnet`, `www`, `api-ssl` | Disable |
| `ftp` | Disable |
| **`reverse-proxy`** | Disable if using Caddy for HTTPS (not the same as www-ssl) |
| **`api`** | Disable **unless** CrowdSec bouncer needs it — then bind `address=` to bouncer IP only (e.g. Caddy host) |
| Bandwidth-test server | Disable or restrict |
| UPnP / SOCKS / web proxy | Off |

> [!TIP]
> RouterOS **`reverse-proxy`** is a built-in SNI proxy on :443. Public apps should use **Caddy + DSTNAT**, not this service.

---

## Firewall Strategies (current)

> [!WARNING]
> Prefer a **final drop** on `forward` and tight `input` after explicit allows. Large rule sets cost CPU; keep comments clear.

### Interface lists (primary)

| List | Members (example) |
|------|-------------------|
| **LAN** | main `bridge`, `wireguard1` |
| **WAN** | `ether1`, `pppoe-out1` |
| **Untrusted** | `homelab-bridge`, `guest-vlan` |

### Forward skeleton

1. CrowdSec / established / fasttrack / invalid  
2. Pinholes (DNS to AdGuard, AI API, AnyType→WG, Untrusted hairpin DSTNAT, …)  
3. **Untrusted → WAN** accept  
4. **Isolate Homelab & IoT** (`Untrusted` → `All private subnets` drop)  
5. **LAN → WAN** and **LAN → other** accepts  
6. **DSTNAT** accept  
7. **Drop WAN not DSTNAT** (stock)  
8. **Drop all other forward** (default deny)

### Input skeleton

1. Established / invalid / ICMP / loopback  
2. WG handshake; pinholes (CrowdSec API, agent SSH, …)  
3. Port knock + rate-limited SSH from LAN + drop other SSH  
4. **`drop !LAN`**  
5. **Allow LAN remaining input** + **drop all other input**

### Address lists

Use for pinholes (`AI servers`, `DNS-Servers`) and isolation (`All private subnets`). Weaker alone than interface lists (IP spoofing) but fine for exceptions.

### detect-internet

```bash
/interface detect-internet set detect-interface-list=none
```

Do not auto-classify interfaces when lists are hand-maintained.

### Resources

- [MikroTik default firewall discussion](https://forum.mikrotik.com/t/buying-rb1100ahx4-dude-edition-questions-about-firewall/148996/4)
- Private audit: `docs_private/security/mikrotik-firewall-audit.md` (if present in vault)

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

> [!WARNING]
> MAC-based access bypasses IP firewall rules and is visible to anyone on the same L2 segment. Lockdown is essential to remove hidden Layer 2 management backdoors.

### Neighbour Discovery

**IP** → **Neighbors** → **Discovery Settings**:
Disable discovery on WAN, Guest, and IoT interfaces to prevent information leakage (MACs, IPs, Identity, Version).

### Bruteforce Protection

MikroTik can detect and blacklist IPs after multiple failed attempts. This is highly recommended for any service exposed to the LAN or WAN.

**Applicable Services:**
- **WinBox** (TCP/8291)
- **HTTPS WebFig** (TCP/**8443** — not public 443; that is Caddy)
- **SSH** (should not be WAN-open)
- **Port-scan detection** / **SYN flood** (optional extras)

**The Logic:**
1. 1st failed attempt → `stage1` address list.
2. 2nd failed attempt → `stage2` address list.
3. 3rd failed attempt → **Blacklisted** for 24 hours.

### Disable Unused Interfaces

A "Physical Security" best practice. Disabling unused ports (`etherX`) prevents unauthorized devices (e.g., from a guest or intruder) from gaining immediate network access by plugging in a cable.

### DNS Hardening

```bash
/ip dns set cache-max-ttl=24h
```

Clients: DHCP dual DNS (`[ADGUARD-IP],1.1.1.1`) — see [setup.md](setup.md). Do not rely on the router as the house resolver.

### NTP

```bash
/system ntp client set enabled=yes
/system ntp client servers add address=time.cloudflare.com
/system ntp client servers add address=0.uk.pool.ntp.org
```

### Winbox source restriction (optional)

```bash
/ip service set winbox address=[LAN-SUBNET],[WG-SUBNET]
```

(www-ssl often left unrestricted at the service layer so port-knock Web UI works; firewall still gates WAN.)

---

## Verification & Testing

### WAN Access Test

Verify that management interfaces are NOT accessible from the public IP:
- `curl http://[PUBLIC-IP]:8443` (Should timeout).
- Check `IP > Firewall > Filter Rules` for the rule: `defconf: drop all not coming from LAN`.

### The "Escape" Test

Verify firewall isolation by attempting to move from an untrusted to a trusted zone.
- **How**: SSH into a **Homelab Server** (`[HOMELAB-IP]`) and attempt to ping a device on the **Trusted LAN** (`[TRUSTED-IP]`).
- **Success**: The ping MUST timeout or be refused. If it works, the "Drop" rule is likely in the wrong order.

### Port Scanning & Service Discovery

Use `nmap` from the homelab to verify pinhole rules:

```bash
nmap -Pn -p 80,443,445,139,1234 [ROUTER-IP-SECONDARY]
```

- **Expected**: Port `1234` is **open**, others are **filtered**.

Verify SMB isolation using the Samba client:

```bash
smbclient -L //[TRUSTED-IP] -N
```

- **Expected**: `Connection failed (Error NT_STATUS_IO_TIMEOUT)`.

---

## Appendix A: Legacy hardening snippets

### Forward SSH rate-limit (retired / disabled)

Optional cross-subnet throttle; little value if SSH is not WAN-published. Same-subnet SSH never hits `forward`.

```bash
/ip firewall filter add chain=forward action=accept connection-state=new protocol=tcp \
    dst-port=22 dst-limit=2/1m,5,src-address/1m40s comment="RATE LIMIT: Accept SSH within limit"
/ip firewall filter add chain=forward action=drop connection-state=new protocol=tcp \
    dst-port=22 comment="RATE LIMIT: Drop excessive SSH attempts"
```

### Disable API entirely

Older guidance said disable `api`. **Current:** CrowdSec RouterOS bouncer uses API from the Caddy host — keep `api` bound to that IP only, or break the bouncer.

### Full ASUS DMZ + “Don’t DMZ WireGuard”

See [setup.md Appendix A](setup.md) and [vpn-setup.md Appendix A](vpn-setup.md).