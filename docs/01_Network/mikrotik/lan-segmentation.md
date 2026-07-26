> [!NOTE]
> **Tags:** #MikroTik #Segmentation #Bridge #Firewall

# Isolating the Homelab Network

## Uniting `ether3` and `ether4` (The Homelab Switch)

To make `ether3` and `ether4` talk to each other while sharing the `[HOMELAB-GW]` gateway, create a **separate bridge** (physical switch for the lab).

### Create the New Bridge

1. **Bridge** → **New** → Name: `homelab-bridge`.

### Move Ports

1. **Bridge** → **Ports**: remove `ether3` / `ether4` from `bridge`.
2. Add them to `homelab-bridge`.

### Address + DHCP

1. **IP** → **Addresses**: `[HOMELAB-GW]/24` on `homelab-bridge`.
2. **IP** → **DHCP Server** → Setup on `homelab-bridge`.

**DNS on the DHCP network** (not the gateway):

```bash
/ip dhcp-server network set [find comment=homelab] \
    dns-server=[ADGUARD-IP]
```

Same AdGuard-only DHCP DNS as main LAN and guest (see [setup.md](setup.md) / AdGuard docs). Failover is router-side (`CheckAdGuard`), not a public secondary on DHCP.

### Interface list

Put the lab (and guest VLAN) on **Untrusted**:

```bash
/interface list member add interface=homelab-bridge list=Untrusted comment=Homelab
/interface list member add interface=guest-vlan list=Untrusted comment="Guest network"
```

**LAN** list = main `bridge` + `wireguard1` (trusted management).  
**WAN** = `ether1` + `pppoe-out1`.

---

## Bridge VLAN filtering (Guest + Asus trunk)

> [!IMPORTANT]
> `vlan-filtering=yes` on main `bridge`. Without this, `/interface bridge vlan` is only partly enforced and Guest VLAN frames can flood onto other bridge ports (e.g. `ether5`, `sfp1`). Firewall isolation still applies to **routed** traffic; filtering hardens **L2**.

### Topology (why this is needed)

```text
Main SSID  ── untagged ──┐
                         ├── Asus (AP mode) ── trunk ── ether2 ── MikroTik bridge
Guest SSID ── VLAN 10 ───┘
```

| Path | Role |
|------|------|
| `ether2` | Trunk to Asus: **untagged** main LAN + **tagged** VLAN 10 (guest) |
| `ether5`, `sfp1` | Access ports: main LAN only (untagged / PVID 1) |
| `guest-vlan` | VLAN interface on `bridge`, `vlan-id=10`, list **Untrusted** |
| `homelab-bridge` | Separate bridge (ether3/4) — **not** affected by main-bridge filtering |

Asus must tag the guest (and any IoT-as-guest) SSID as **VLAN 10**. If both networks leave the AP untagged, MikroTik cannot separate them.

### Target config (RouterOS 7)

```bash
# Access / trunk port roles (main bridge only)
/interface bridge port
set [find where bridge=bridge and interface=ether2] \
    pvid=1 frame-types=admit-all \
    comment="Trunk to Asus AP (untagged main + VLAN 10 guest)"
set [find where bridge=bridge and interface=ether5] \
    pvid=1 frame-types=admit-only-untagged-and-priority-tagged \
    comment="Main LAN access"
set [find where bridge=bridge and interface=sfp1] \
    pvid=1 frame-types=admit-only-untagged-and-priority-tagged \
    comment="Main LAN access"

# VLAN table
/interface bridge vlan
# Main LAN (untagged / PVID 1) — CPU + all main ports
add bridge=bridge comment="Main LAN (untagged)" \
    untagged=bridge,ether2,ether5,sfp1 vlan-ids=1
# Guest — tagged on CPU + Asus trunk only (no ether5/sfp1)
add bridge=bridge comment="Guest VLAN" \
    tagged=bridge,ether2 vlan-ids=10

# Enable enforcement LAST
/interface bridge set [find name=bridge] vlan-filtering=yes
```

If a row already exists, use `set [find ...]` instead of `add`.

### Safe apply order

1. Manage the router from **homelab** (`[HOMELAB-GW]` / `192.168.50.1`) or another path that does **not** depend on the main-bridge port you might mis-tag.  
2. Set **port PVIDs / frame-types** and **bridge vlan** rows first.  
3. Enable **`vlan-filtering=yes` last**.  
4. Verify: main Wi‑Fi DHCP, guest Wi‑Fi DHCP on guest subnet, guest cannot reach main LAN / lab private ranges, `ether5`/`sfp1` do not carry VLAN 10.

### What this does *not* replace

- Firewall **Isolate Homelab & IoT** (Untrusted → private) still required for L3.  
- Homelab isolation remains the **separate bridge**, not guest VLAN filtering.  
- ASUS guest isolation / client isolation is optional extra, not a substitute for tagging + filtering.

---

## Firewall (current model)

### Isolation: Untrusted → private

Drop Homelab/guest initiated traffic to RFC1918 (and friends) **except** explicit pinholes above this rule:

```bash
/ip firewall filter add chain=forward action=drop \
    in-interface-list=Untrusted dst-address-list="All private subnets" \
    log=yes log-prefix=isolate_untrusted_lan \
    comment="Isolate Homelab & IoT"
```

### Internet for Untrusted

```bash
/ip firewall filter add chain=forward action=accept \
    in-interface-list=Untrusted out-interface-list=WAN \
    comment="Allow Untrusted to internet (WAN)" \
    place-before=[find where comment="Isolate Homelab & IoT"]
```

### DNS punch-hole to AdGuard (forward)

```bash
/ip firewall address-list add address=[ADGUARD-IP] list=DNS-Servers comment="AdGuard Home"

/ip firewall filter add chain=forward action=accept protocol=udp \
    dst-address-list=DNS-Servers dst-port=53 \
    comment="Allow all internal DNS queries to AdGuard (UDP)" \
    place-before=[find where comment="Isolate Homelab & IoT"]

/ip firewall filter add chain=forward action=accept protocol=tcp \
    dst-address-list=DNS-Servers dst-port=53 \
    comment="Allow all internal DNS queries to AdGuard (TCP)" \
    place-before=[find where comment="Isolate Homelab & IoT"]
```

### Homelab → AI servers (pinhole)

Above isolate; use an address-list of AI hosts on the trusted LAN:

```bash
/ip firewall filter add chain=forward action=accept protocol=tcp \
    src-address=[HOMELAB-SERVER-IP] dst-address-list="AI servers" \
    dst-port=1234,8188 comment="Allow Homelab to access AI API" \
    place-before=[find where comment="Isolate Homelab & IoT"]
```

### Router management from Homelab

Homelab is **Untrusted** → blocked by `drop all not coming from LAN` for input, **except** explicit allows (e.g. agent SSH from ai-tools — see [ai-ssh-access.md](ai-ssh-access.md)). Do **not** open general Homelab → router admin.

### Default deny (forward)

After intentional accepts (LAN→WAN, LAN→other, DSTNAT, Untrusted→WAN, pinholes):

```bash
/ip firewall filter add chain=forward action=drop log=yes \
    log-prefix=drop_forward_default comment="Drop all other forward (default deny)"
```

---

## Zero Trust layers

- **Layer 1 (MikroTik L3):** Interface lists + isolate + pinholes  
- **Layer 1b (MikroTik L2):** Bridge **VLAN filtering** on main `bridge` (guest trunk vs access ports) — see above  
- **Layer 2 (Asus AP / main LAN):** Correct SSID→VLAN tagging; host placement on trusted L2  
- **Layer 3 (Host OS):** Host firewall / app auth  

---

## Appendix A: Legacy segmentation recipes

### Homelab DHCP DNS = gateway

Old text set DNS to `[HOMELAB-GW]`. **Retired** — use AdGuard only on the DHCP network (+ router health script for outages).

### Input allows for Homelab → router DNS

```bash
# Disabled / pending delete — clients should not use the router as DNS
/ip firewall filter add chain=input src-address=[HOMELAB-SUBNET]/24 \
    protocol=udp dst-port=53 action=accept comment="Allow Homelab DNS UDP"
/ip firewall filter add chain=input src-address=[HOMELAB-SUBNET]/24 \
    protocol=tcp dst-port=53 action=accept comment="Allow Homelab DNS TCP"
```

### Subnet-only isolate (no interface list)

```bash
/ip firewall filter add chain=forward src-address=[HOMELAB-SUBNET]/24 \
    dst-address=[TRUSTED-LAN-SUBNET]/24 action=drop \
    comment="Isolate Homelab from Trusted LAN"
```

Prefer **`in-interface-list=Untrusted`** + **`All private subnets`** so guest + lab share one rule and spoofing a “trusted” IP on an untrusted port does not help.

### Asus WAN port-translation for AI APIs

Older design: Homelab → Asus WAN IP with port maps per PC. Current design uses MikroTik forward pinhole to **`AI servers` address-list** on main LAN IPs directly (when routing allows).
