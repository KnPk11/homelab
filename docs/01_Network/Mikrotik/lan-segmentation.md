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
    dns-server=[ADGUARD-IP],1.1.1.1
```

Same dual-DNS pattern as main LAN and guest (see [setup.md](setup.md) / AdGuard docs).

### Interface list

Put the lab (and guest VLAN) on **Untrusted**:

```bash
/interface list member add interface=homelab-bridge list=Untrusted comment=Homelab
/interface list member add interface=guest-vlan list=Untrusted comment="Guest network"
```

**LAN** list = main `bridge` + `wireguard1` (trusted management).  
**WAN** = `ether1` + `pppoe-out1`.

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

- **Layer 1 (MikroTik):** Interface lists + isolate + pinholes  
- **Layer 2 (Asus AP / main LAN):** Host placement on trusted L2  
- **Layer 3 (Host OS):** Host firewall / app auth  

---

## Appendix A: Legacy segmentation recipes

### Homelab DHCP DNS = gateway

Old text set DNS to `[HOMELAB-GW]`. **Retired** — use AdGuard + `1.1.1.1` on the DHCP network.

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
