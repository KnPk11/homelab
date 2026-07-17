> [!NOTE]
> **Tags:** #MikroTik #Setup #Networking #IPv6

> [!IMPORTANT]
> **Architecture Note:** This configuration utilises a **dual-router setup**. The MikroTik serves as the primary gateway and homelab router, while a secondary Asus router is utilised primarily in **Access Point (AP) mode** for the trusted LAN.

# Basic Setup

## Networking

Set a static IP for the secondary router (Asus):

1. **IP** → **DHCP Server**.
2. Select the device and click **Make Static**.
3. After doing that, change the IP to `[ROUTER-IP-SECONDARY]` (e.g., `192.168.88.2`) for convenience.

## DNS

### Client DNS (DHCP — preferred)

Hand clients **only AdGuard** so filtering and local rewrites always apply (no public secondary that clients can race to):

```bash
/ip dhcp-server network
set [find comment=defconf] dns-server=[ADGUARD-IP]
set [find comment=homelab] dns-server=[ADGUARD-IP]
set [find comment=guest-vlan] dns-server=[ADGUARD-IP]
```

**Resilience when dns-102 is down:** MikroTik script `CheckAdGuard` + scheduler `DNS_Health_Check` (every 1m) plus the **AdGuard Failover Trap** NAT. See [AdGuard Home setup — DNS failover](../../02_Services/AdGuard%20Home/setup.md#client-dns-via-mikrotik-dhcp-current).

> [!NOTE]
> Dual DHCP DNS (`[ADGUARD-IP],1.1.1.1`) was tried for simple client failover but causes **random AdGuard bypass** (clients often query both resolvers). Prefer AdGuard-only + router health script.

See also [AdGuard Home setup](../../02_Services/AdGuard%20Home/setup.md) (upstream resolvers, punch-hole rules).

### Router DNS service

Interfaces → `pppoe-out` → **Dial Out** → Uncheck **Use Peer DNS**.  
**IP** → **DHCP Client** → `ether1` → Uncheck **Use Peer DNS** (optional).

**IP** → **DNS**:
- Ensure **Dynamic Servers** is empty.
- **Servers:** `[ADGUARD-IP]` while healthy; script may switch to `9.9.9.9` during failover.
- **Allow Remote Requests:** **yes** (needed so the Failover Trap can answer client queries redirected to the router). Normal clients still use `[ADGUARD-IP]` from DHCP; they only hit the router when the trap is enabled.

### Split-horizon / hairpin statics (current)

LAN/VPN access to your public hostname via the router (port-based DSTNAT: 80/443 → Caddy, app ports → services):

```bash
/ip dns static add name=[DOMAIN] address=[HOMELAB-GW] match-subdomain=yes \
    comment="Hairpin via GW for port-based DSTNAT"
```

Older name-based splits (per-host A records only) — see Appendix B.

## DDNS

1. **IP** → **Cloud** → **DDNS Enabled**.
2. **DDNS Update Interval**: `(not required)`.
3. Wait until a domain is generated under **DNS Name**: `[DDNS_NAME].sn.mynetname.net`.

## Port Forwarding

Add port-forwarding rules under **IP** → **Firewall** → **NAT**.
**Comment**: Name of the rule.

**General:**
- **Chain**: `dstnat`
- **Protocol**: `<tcp/udp>`
- **Dst. Port**: `<port number>`

**Action:**
- **Action**: `dst-nat`
- **To addresses**: `[SERVER-IP]`
- **To Ports**: `<port number>`

**Extra:**
- **Dst. Address Type**: `local`

> [!NOTE]
> - **Real Internet Traffic**: Comes from the outside world → Hits the WAN port → Matches the rule → WORKS.
> - **WireGuard Traffic**: Comes from your secondary router (which is inside your network) → Hits the MikroTik's LAN port → DOES NOT MATCH "WAN" → The rule is ignored.
> - To fix this, remove `WAN` from **In. Interface List** and add **Dst. Address Type**: `local` under **Extra**.

## Secondary Router Admin Page

Secondary router (Asus): Use `https://[INTERNAL-IP]:8443`.
If that doesn't work, enable access from WAN and go to `https://[ROUTER-IP-SECONDARY]:8443`, but then set a firewall rule in MikroTik to prevent outside access.

## "Break-glass" Access Recovery

- Use **Safe Mode** to avoid locking yourself out remotely.
- Use **Port Knocking** for "break-glass" access to the router (refer to `port-knocking.md`).

> [!NOTE]
> Port knocking is technically **"Security through Obscurity"** and is best used as an **Emergency Backdoor**. It acts like a spare key hidden under a rock. For daily use, a **WireGuard VPN** is vastly superior.

## IPv6

> [!WARNING]
> Ensure you verify the security of your IPv6 firewall rules.

1. **Request the Address Block from the ISP**

**IPv6** → **DHCP Client** → **New**:
- **Interface**: `pppoe-out1`
- **Request**: Check **Prefix** only
- **Pool Name**: `ipv6-pool`
- **Pool Prefix Length**: `60`
- **Prefix Hint**: `::/0`
- **Use Peer DNS**: `yes`

2. **Give the MikroTik an IPv6 Address**

**IPv6** → **Addresses** → **New**:
- **Address**: `::1/64` (pick the first address from the pool)
- **From Pool**: `ipv6-pool`
- **Interface**: `bridge`
- **Advertise**: Checked.

3. **Pass IPv6 to the Secondary Router (Prefix Delegation)**

**IPv6** → **DHCP Server** → **New**:
- **Name**: `server1`
- **Interface**: `bridge`
- **Prefix Pool**: `ipv6-pool`
- **Address Pool**: `ipv6-pool`
- **Lease Time**: `1d 00:00:00`

**Important ND Setting:** **IPv6** → **ND** (Neighbor Discovery). Open the default entry for your bridge and ensure **Managed Address Configuration** and **Other Configuration** are unchecked for simple SLAAC passthrough.

4. **Set Up Firewall Rules**

**IPv6** → **Firewall** → **Filter Rules** → **New**:
- **Chain**: `forward`
- **In. Interface**: `bridge`
- **Out. Interface**: `pppoe-out1`
- **Action**: `accept`

Drag and drop this rule so it sits above the final **Drop** rule.

5. **Configure the Secondary Router (IPv6 Passthrough)**

Set the connection type to **Native** (recommended) or **Passthrough**.

> [!NOTE]
> **Native** should detect the DHCPv6 server on the MikroTik and request a prefix. If **Native** fails, try **Passthrough**.

# Updating

Ensure you periodically check for and install updates:
- **RouterOS**: **System** → **Packages** → **Check For Updates**.
- **Firmware**: **System** → **RouterBOARD**.

---

## Appendix A: Legacy — full ASUS DMZ (retired)

> [!WARNING]
> **Not used** with Asus in **AP mode**. A full WAN DMZ to the secondary router was removed (security audit / changelog 2026-07). Prefer explicit DSTNAT pinholes (Caddy, apps) and MikroTik WireGuard.

Historical recipe (do **not** re-enable casually):

**IP** → **Firewall** → **NAT** → **Add**:

- **Chain**: `dstnat`
- **In. Interface**: `pppoe-out1`
- **Action**: `dst-nat`
- **To Addresses**: `[ROUTER-IP-SECONDARY]`

Place below specific homelab pinholes (80/443, etc.) and above masquerade. Pair with care so MikroTik WireGuard `:51821` is not swallowed (old “Don’t DMZ WireGuard” accept is also retired).

---

## Appendix B: Legacy DNS static patterns

```bash
# Exact match first
/ip dns static add name=stream.[DOMAIN] address=[SERVER-IP]
# Regexp catch-all to reverse proxy only (breaks multi-host port split on one name)
/ip dns static add regexp=".*\\.[DOMAIN]" address=[CADDY-IP]
```

Prefer **gateway IP + DSTNAT by port** when one hostname serves Caddy and other host ports (e.g. AnyType).

ASUS DDNS internal resolve (if needed):

- **Name:** `[ASUS-DDNS]` → **Address:** `[ROUTER-IP-SECONDARY]`
