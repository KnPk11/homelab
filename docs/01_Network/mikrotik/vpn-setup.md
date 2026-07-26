> [!NOTE]
> **Tags:** #MikroTik #VPN #WireGuard #Networking

# Virtual Private Networks (VPN)

**Current edge VPN:** MikroTik WireGuard on WAN (`listen-port` **51821**). Asus is **AP mode** — do not forward WG/OpenVPN to the Asus.

---

## 🛡️ Multi-Tier Remote Access & Failover Model

The homelab utilizes a 4-tier remote access hierarchy to ensure 100% remote management resilience:

```mermaid
flowchart TD
    classDef primary fill:#1e293b,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef fallback fill:#1e293b,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef emergency fill:#1e293b,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef hardware fill:#1e293b,stroke:#ef4444,stroke-width:2px,color:#fff
    classDef target fill:#0f172a,stroke:#10b981,stroke-width:2px,color:#fff

    User(["📱 Remote Admin / User"]):::target

    subgraph Tier1 ["Tier 1: Primary Remote Access"]
        WG["🔒 MikroTik WireGuard<br/>(192.168.88.1 : 51821)"]:::primary
    end

    subgraph Tier2 ["Tier 2: Fallback Remote Access"]
        TS["🌐 Tailscale LXC 'vpns'<br/>(CT 108 : 192.168.50.87)"]:::fallback
    end

    subgraph Tier3 ["Tier 3: Router Emergency Recovery"]
        PK["⚡ MikroTik Port Knocking<br/>(Dynamic Allowlist Rule)"]:::emergency
    end

    subgraph Tier4 ["Tier 4: Physical Hardware & Hard-Power Recovery"]
        SP["🔌 Cloud Smart Plugs<br/>(Hard AC Power Cycle)"]:::hardware
        BIOS["🖥️ Physical PC BIOS<br/>(Restore AC Power = Always On)"]:::hardware
        AD["💻 AnyDesk Remote Desktop<br/>(LAN PC Access)"]:::hardware
    end

    LAN[("🏠 Homelab LAN Infrastructure<br/>(Proxmox, VMs, Storage)")]:::target

    User -->|Daily Native Access| WG
    User -->|Fallback if WG Fails| TS
    User -->|If Locked Out of Router| PK
    User -->|If Host Powered Off| SP

    WG -->|Direct HW Routing| LAN
    TS -->|Subnet Routing| LAN
    PK -->|Restore WinBox/SSH| WG
    SP -->|Trigger Power Restore| BIOS
    BIOS -->|Auto-Boot System| AD
    AD -->|LAN Access| LAN
```

### **Access Tiers Summary**
* **Tier 1 (Primary)**: MikroTik WireGuard (`listen-port 51821`) — Native high-speed WAN gateway.
* **Tier 2 (Fallback)**: Tailscale LXC (`vpns` / CT 108 / `192.168.50.87`) — Mesh VPN fallback with NAT traversal & subnet routing.
* **Tier 3 (Emergency Lockout)**: MikroTik Port Knocking — Secret packet sequence to unblock management access if firewall rules lock out standard ports.
* **Tier 4 (Hardware Recovery)**: App-managed Smart Plugs + BIOS AC Power Restore + AnyDesk on LAN PCs for hard power cycling and out-of-band desktop recovery.

---

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

Treats WG clients as trusted for management (same as main LAN list membership):

```bash
/interface list member add interface=wireguard1 list=LAN
```

### 4. Client peer on phone/laptop and on MikroTik

```bash
/interface wireguard peers add interface=wireguard1 public-key="[CLIENT-PUBLIC-KEY]" \
    allowed-address=[WG-SUBNET].2/32 comment="[CLIENT-NAME]"
```

### 5. Firewall & NAT (current)

**Allow WireGuard handshake (WAN input):**

```bash
/ip firewall filter add action=accept chain=input protocol=udp dst-port=51821 \
    in-interface-list=WAN comment="Allow WireGuard handshake" log=yes log-prefix=wg_handshake
```


**MSS clamp** (avoids TCP black holes on the tunnel):

```bash
/ip firewall mangle
add action=change-mss chain=forward in-interface=wireguard1 new-mss=clamp-to-pmtu \
    protocol=tcp tcp-flags=syn comment="Clamp TCP MSS for WireGuard (in)"
add action=change-mss chain=forward out-interface=wireguard1 new-mss=clamp-to-pmtu \
    protocol=tcp tcp-flags=syn comment="Clamp TCP MSS for WireGuard (out)"
```

---

## Client Configuration (Example)

- **Addresses:** `[WG-SUBNET].2/32`
- **DNS:** Prefer **`[ADGUARD-IP]`** only (same as house DHCP). Using only `[WG-SUBNET].1` forces all client queries through the router.
- **Allowed IPs:** `0.0.0.0/0` (full tunnel) or split as needed
- **Endpoint:** `[DDNS_NAME].sn.mynetname.net:51821`
- **Public Key:** `[ROUTER-WG-PUBLIC-KEY]`

