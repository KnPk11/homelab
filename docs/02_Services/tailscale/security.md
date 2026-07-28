# Tailscale Security

> [!NOTE]
> #Tailscale #Security #VPN #Networking #Firewall

Firewall, ACLs, and access hygiene for Tailscale. Install and verification live in [setup.md](setup.md).

## 1. Description

Tailscale is a WireGuard-based mesh VPN. Security in this lab is mostly **identity and policy** (tags/ACLs) plus correct **firewall treatment of UDP 41641** and awareness that mesh traffic does not always hit the same path as LAN UFW rules.

## 2. Firewall & Port Forwarding

### Proxmox Guest Firewall (`eth0`)

Tailscale listens for direct WireGuard peers on **UDP 41641**. Without **41641** open, Tailscale still works via **DERP relays** (slower, higher latency). Opening 41641 on the guest firewall enables **direct** peer paths when NAT allows.

### Edge / Router Port Forward (MikroTik DNAT)

For optimal peer-to-peer connectivity when your node is behind NAT, forward **UDP 41641** to the Tailscale node on the router.

## 3. Access Control Lists (ACLs)

Utilise tags to manage permissions effectively, especially for "untrusted" nodes.

1. Go to **Access Controls** > **Create Tag**.
2. Choose a name (e.g., `homelab`), set the tag owner, and save.
3. Go to **Machines** > [DEVICE] > `...` > **Edit ACL tags...**.
4. Add the tag and save.
5. In **Access Controls**, use the JSON editor to apply the required configuration.

> [!NOTE]
> **ACL Example Configuration**:
>
> ```json
> {
>   // 1. Define Tag Owners
>   // We use "autogroup:admin" directly here.
>   // This means anyone with Admin rights (You) can manage this tag.
>   "tagOwners": {
>     "tag:homelab": ["autogroup:admin"],
>   },
>
>   // 2. The Rules (ACLs)
>   "acls": [
>     // Rule A: Admins (You) can access EVERYTHING.
>     // "autogroup:admin" covers your email (knpk11@github) automatically.
>     {
>       "action": "accept",
>       "src": ["autogroup:admin"],
>       "dst": ["*:*"]
>     },
>
>     // Rule B: The Homelab can access the Internet.
>     // Required for Exit Node usage and updates.
>     {
>       "action": "accept",
>       "src": ["tag:homelab"],
>       "dst": ["autogroup:internet:*"]
>     },
>
>     // Rule C: The Homelab can talk to ITSELF.
>     // Good for internal health checks or Docker containers.
>     {
>       "action": "accept",
>       "src": ["tag:homelab"],
>       "dst": ["tag:homelab:*"]
>     }
>   ]
> }
> ```

Test that an "untrusted" node is unable to access SMB shares on a "trusted" LAN PC (after ACLs from [security.md](security.md)):

```bash
sudo apt-get install smbclient

# Using LAN IP
smbclient -L //[LAN-PC-IP] -U [USER]

# Using Tailscale IP
smbclient -L //[TAILSCALE-IP] -U [USER]
```

The connection should fail. If it succeeds, verify the SMB whitelist on the target PC and ensure the Tailscale ACLs are restrictive.

## 4. Best Practices

- **Firewalls are not fully “bypassed”**:
  - Traffic on the **Tailscale interface** (`tailscale0` / userspace) often does **not** behave like normal UFW rules for mesh peers.
  - Traffic that hits the node on **LAN/WAN eth0** (including **UDP 41641** for direct WireGuard) **still** passes **Proxmox guest firewall**, host rules, and the **router**. Open 41641 where you want direct paths; do not assume “Tailscale ignores PVE.”
- **Zero Trust hybrid**: for high-speed transfers on a trusted LAN, use a strict host allow-list to prefer local IPs over Tailscale encryption when both peers are on-LAN.
- **Sharing access**: use **Share Machine** instead of adding people to the full Tailnet when you want isolation (they only see the shared device).
