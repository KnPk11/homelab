> [!NOTE]
> **Tags:** #MikroTik #VPN #WireGuard #Networking

# Virtual Private Networks (VPN)

## WireGuard Server Setup

### 1. Create WireGuard Interface
```bash
/interface wireguard add name=wireguard1 listen-port=51821 mtu=1420 comment="WireGuard server"
```

### 2. Assign IP Subnet to WireGuard
```bash
/ip address add address=[WG-SUBNET].1/24 interface=wireguard1 comment="WG subnet"
```

### 3. Add WireGuard to LAN Interface List
```bash
/interface list member add interface=wireguard1 list=LAN
```

### 4. Add Client Peer
Set up WireGuard on the client device, inputting the public key under the `peer` section.

### 5. Add Client Peer
On the MikroTik:
```bash
/interface wireguard peers add interface=wireguard1 public-key="[CLIENT-PUBLIC-KEY]" allowed-address=[WG-SUBNET].2/32 comment="[CLIENT-NAME]"
```

### 6. Firewall Configuration

**Allow WireGuard Handshake (WAN Input):**
```bash
/ip firewall filter add action=accept chain=input protocol=udp dst-port=51821 in-interface-list=WAN comment="Allow WireGuard handshake" place-before=1
```

**Allow WireGuard Clients to Access Router Services:**
```bash
/ip firewall filter add action=accept chain=input src-address=[WG-SUBNET].0/24 in-interface=wireguard1 comment="Allow WG client to access router services" place-before=1
```

**NAT for Internet Access:**
```bash
/ip firewall nat add action=masquerade chain=srcnat src-address=[WG-SUBNET].0/24 out-interface-list=WAN comment="WireGuard VPN NAT"
```

**Ensure DMZ Rule Does Not Interfere:**
```bash
/ip firewall nat add action=accept chain=dstnat protocol=udp dst-port=51821 in-interface-list=WAN comment="Don't DMZ WireGuard" place-before=0
```

---

## Client Configuration (Example)
- **Addresses:** `[WG-SUBNET].2/32`
- **DNS Servers:** `[WG-SUBNET].1` (or your internal AdGuard IP)
- **Allowed IPs:** `0.0.0.0/0` (for full tunnel)
- **Endpoint:** `[DDNS_NAME].sn.mynetname.net:51821`
- **Public Key:** `[ROUTER-WG-PUBLIC-KEY]`
