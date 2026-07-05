# Tailscale Setup

> [!NOTE]
> **Tags:** #Tailscale #Vpn #Networking #DockerCompose

## 1. Description

A mesh VPN based on WireGuard that simplifies secure remote access and networking.

Unlike manual WireGuard configs, Tailscale easily keeps local SMB shares accessible while the tunnel is active. You don't need to enable an exit node to access your LAN shares.

## 2. Installation (Native)

1. **Install Tailscale**
   
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   ```

2. **Enable IP Forwarding**
   
   ```bash
   echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
   sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
   ```

3. **Configure Routing**
   Go to the Admin Console, select your device, navigate to **Edit Route Settings**, and toggle the switch **ON**.

4. **Start the Service**
   
   ```bash
   # Without LAN sharing
   sudo tailscale up --advertise-exit-node --advertise-routes=

   # With LAN subnet (ensure proper ACLs are configured)
   sudo tailscale up --advertise-exit-node --advertise-routes=[LAN-SUBNET]
   ```

   > [!TIP]
   > **Subnet Advertising**: Multiple subnets can be advertised as a comma-separated list:
   > 
   > ```bash
   > --advertise-routes=[SUBNET-1],[SUBNET-2]
   > ```

5. **UDP GRO Forwarding**
   > [!NOTE]
   > **UDP GRO Forwarding Warning**: If you see a warning regarding suboptimal UDP GRO forwarding, execute the following:
   
   ```bash
   sudo ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
   ```

   To persist this after reboot, add it to `sudo crontab -e`:
   
   ```bash
   @reboot /usr/sbin/ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
   ```

6. **Disable Key Expiry**
   1. Open the [Tailscale Admin Console](https://login.tailscale.com/admin/machines).
   2. Locate your device in the list.
   3. Select `...` > **Disable Key Expiry**.

7. **Authorise as Exit Node**
   1. In the Admin Console, find your device.
   2. Select `...` > **Edit Route Settings**.
   3. Enable **Use as exit node**.

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

## 4. Verification

Test that the "untrusted" node is unable to access SMB shares on a "trusted" LAN PC:

```bash
sudo apt-get install smbclient

# Using LAN IP
smbclient -L //[LAN-PC-IP] -U [USER]

# Using Tailscale IP
smbclient -L //[TAILSCALE-IP] -U [USER]
```

The connection should fail. If it succeeds, verify the SMB whitelist on the target PC and ensure the Tailscale ACLs are restrictive.

## 5. Security & Best Practices

- **Firewall Bypassing**: Tailscale bypasses traditional firewall rules (UFW/Windows Firewall), so additional configuration there is typically unnecessary for Tailnet traffic.
- **Zero Trust Hybrid Setup**: For high-speed transfers on a trusted LAN, utilise a strict allow-list on the host PC to bypass Tailscale's encryption overhead only for specific whitelisted local IPs.
- **Sharing Access**: When sharing access with others, utilise the **Share Machine** feature instead of adding them to the full Tailnet. This provides total isolation, allowing them to see only the shared device.

## 6. Troubleshooting

### DNS Fight on Debian (resolv.conf conflict)

> [!WARNING]
> On Debian hosts, Tailscale's MagicDNS and NetworkManager can fight over `/etc/resolv.conf`. This causes DNS resolution to stall entirely — breaking git pulls, Docker image pulls, apt updates, and all outbound connectivity.

**Symptoms:** Intermittent DNS failures, services unable to resolve hostnames.

**Root Cause:** Debian doesn't ship with a DNS arbiter (like `systemd-resolved`). Both Tailscale and NetworkManager aggressively overwrite `/etc/resolv.conf`, and when one detects its config has been "trampled", DNS stalls during the tug-of-war.

**Fix:** Unless MagicDNS for Tailnet name resolution is needed, disable Tailscale DNS:

```bash
tailscale set --accept-dns=false
```

This hands DNS entirely back to NetworkManager → AdGuard, while Tailscale VPN tunnelling continues to work normally. The change persists across reboots.

> [!NOTE]
> If MagicDNS is needed in the future (e.g., to resolve `*.ts.net` hostnames), the alternative fix is to install a DNS arbiter: `apt-get install resolvconf`.

### Android App Updates

> [!NOTE]
> **Android Update Indicator**: A red exclamation mark next to the account in the Android app may indicate a repository update that the Google Play Store has not yet received. This can generally be ignored.
