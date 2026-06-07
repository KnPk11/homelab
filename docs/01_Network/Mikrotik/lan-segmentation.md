> [!NOTE]
> **Tags:** #MikroTik #Segmentation #Bridge #Firewall

# Isolating the Homelab Network

## Uniting `ether3` and `ether4` (The Homelab Switch)

To make `ether3` and `ether4` talk to each other while sharing the `[HOMELAB-GW]` gateway, you should create a **separate bridge**. This acts as a "physical switch" dedicated to your lab.

### Create the New Bridge

1. Go to **Bridge** → **New**.
2. Name: `homelab-bridge`.
3. Click **OK**.

### Remove the Ports from Existing Bridge

1. Go to **Bridge** → **Ports**.
2. Remove `ether3`.
3. Remove `ether4`.

### Assign Ports to the New Bridge

1. Go to **Bridge** → **Ports**.
2. Add `ether3` → Interface: `ether3`, Bridge: `homelab-bridge`.
3. Add `ether4` → Interface: `ether4`, Bridge: `homelab-bridge`.

### Create a Subnet for the New Bridge

1. Go to **IP** → **Addresses** → **New**.
2. Address: `[HOMELAB-GW]/24`.
3. Network: `[HOMELAB-SUBNET]`.
4. Interface: `homelab-bridge`.

### Create a DHCP Server for the New Bridge

1. Go to **IP** → **DHCP Server** → **DHCP Setup**.
2. DHCP Server Interface: `homelab-bridge`.
3. DHCP Address Space: It should auto-detect `[HOMELAB-SUBNET]/24`.
4. Gateway for DHCP Network: `[HOMELAB-GW]`.
5. Addresses to Give Out: `[HOMELAB-DHCP-RANGE]`.

After that, go to the **Networks** tab, select `homelab-bridge` and ensure DNS is correctly set to `[HOMELAB-GW]`.

**Result:** `ether3` and `ether4` can now talk to each other directly at hardware speeds (switching) without hitting the firewall, but both are trapped behind the `[HOMELAB-GW]` gateway for internet/LAN access.

---

## Firewall Rules

### 1. Block the Homelab from Accessing the MikroTik

```bash
# Explicit block rule by subnet
/ip firewall filter add chain=input src-address=[HOMELAB-SUBNET]/24 action=drop comment="Block Homelab Management Access"

# Alternatively, allow only trusted subnets and drop all other traffic
/ip firewall filter add chain=input action=accept src-address-list="Trusted Subnets" comment="Allow Trusted Admins"
```

Move it below any accept rules of the input chain and **ABOVE** the default rule that says `defconf: drop all not coming from LAN`.

### 2. Block the Homelab from Accessing the Trusted LAN

```bash
# Isolate Homelab from Trusted LAN
/ip firewall filter add chain=forward src-address=[HOMELAB-SUBNET]/24 dst-address=[TRUSTED-LAN-SUBNET]/24 action=drop comment="Isolate Homelab from Trusted LAN"
```

Drag this rule above any **Accept** rules for the LAN, but below **Accept Established**.

> [!NOTE]
> **AdGuard DNS**: To ensure the homelab's DNS doesn't break:
> 
> ```bash
> /ip firewall filter add chain=input src-address=[HOMELAB-SUBNET]/24 protocol=udp dst-port=53 action=accept comment="Allow Homelab DNS UDP"
> /ip firewall filter add chain=input src-address=[HOMELAB-SUBNET]/24 protocol=tcp dst-port=53 action=accept comment="Allow Homelab DNS TCP"
> ```

> [!WARNING]
> **Static IP**: Ensure the homelab is connected with a proper static IP. Go to **IP** → **DHCP Server** → **Leases** and verify the entry.

---

## Server Access on the Trusted LAN

For devices on the trusted LAN to accept requests from the homelab (e.g., for AI APIs).

### The "Pinhole" Rule Using Port Translation

You can use the secondary router (Asus) to translate ports, assigning a unique external port to each PC, but mapping them all to internal port `1234`.

> [!NOTE]
> **Example Setup:**
> - **PC 1 (Main):** Call `[ROUTER-IP-SECONDARY]:1234` → Asus sends to `PC1:1234`.
> - **PC 2 (Secondary):** Call `[ROUTER-IP-SECONDARY]:1235` → Asus sends to `PC2:1234`.
>
> On the secondary router (WAN → Port Forwarding):
> - **Service Name:** `LM Studio PC2`
> - **Protocol:** `TCP`
> - **External Port:** `1235`
> - **Internal Port:** `1234`
> - **Internal IP:** `[PC2-INTERNAL-IP]`
> - **Source IP:** `[HOMELAB-SERVER-IP]`

Then, add a firewall exception on the MikroTik above the **Isolate Homelab** rule:

```bash
/ip firewall filter add chain=forward action=accept src-address=[HOMELAB-SERVER-IP] dst-address=[ROUTER-IP-SECONDARY] protocol=tcp dst-port=1234-1240,8188 comment="Allow Homelab to access AI API" place-before=[find comment="Isolate Homelab"]
```

Update your application's API Base URL to `http://[ROUTER-IP-SECONDARY]:1234/v1`.

### Zero Trust Architecture

- **Layer 1 (MikroTik):** Network Segmentation.
- **Layer 2 (Secondary Router):** Port Forwarding/Translation.
- **Layer 3 (Host OS):** Host-based Firewall.

### Secondary Router LAN

Since the secondary router receives traffic on its **WAN port**, its firewall blocks it by default. It is still recommended to add an explicit firewall rule on the secondary router if management is enabled.
