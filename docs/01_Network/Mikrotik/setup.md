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

To allow access to the homelab domain from within the LAN and to differentiate between various services.

```bash
# Exact match (must be listed first)
/ip dns static add name=stream.[DOMAIN] address=[SERVER-IP]

# RegEx catch-all for everything else
/ip dns static add regexp=".*\\.[DOMAIN]" address=[DNS-SERVER-IP]
```

To make the secondary router's VPN work from within the home network:
- **Name:** `[ASUS-DDNS]`
- **Address:** `[ROUTER-IP-SECONDARY]`

Interfaces → `pppoe-out` → **Dial Out** → Uncheck **Use Peer DNS**.
**IP** → **DHCP Client** → `ether1` → Uncheck **Use Peer DNS** (Optional).
**IP** → **DNS**:
- Ensure **Dynamic Servers** is empty now.
- Add Servers: `[ADGUARD-IP]`
- Tick **Allow Remote Requests**.

## DDNS

1. **IP** → **Cloud** → **DDNS Enabled**.
2. **DDNS Update Interval**: `(not required)`.
3. Wait until a domain is generated under **DNS Name**: `[DDNS_NAME].sn.mynetname.net`.

## DMZ

**IP** → **Firewall** → **NAT** → **Add New (+)**.

**General Tab:**
- **Chain**: `dstnat`
- **In. Interface**: `pppoe-out1` (Your WAN connection)

**Action Tab:**
- **Action**: `dst-nat`
- **To Addresses**: `[ROUTER-IP-SECONDARY]`

Drag and drop your new DMZ rule so it sits below your homelab rules (Port 80/443) but above your Masquerade rules.

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
