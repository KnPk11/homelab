# SMB Setup

> [!NOTE]
> **Tags:** #Smb #Samba #Files #Lan #Networking #DockerCompose

## 1. Description

Secure file sharing via SMB/Samba for local network and VPN clients.

## 2. Installation

### **Docker Setup**

**Configuration**

Edit the custom SMB configuration file:

```bash
sudo nano /srv/samba/smb.conf
```

Replace the existing content with the required configuration.

Add the Docker Compose stack to Portainer and start it.

> [!WARNING]
> **Credentials**: Use the supplied `entrypoint.sh` script instead of supplying credentials as plaintext Docker variables.

```yaml
environment:
  - USER=[USER];[SECRET]
```

For multi-user setups:

```yaml
environment:
  - USER=[USER1];[SECRET1],[USER2];[SECRET2]
  - SHARE=main;/shares;no;no;no;[USER1]
```

### **Native Setup**

If installing natively on the host:

```bash
# Install native Samba
sudo apt install samba -y

# Add your user to Samba
sudo smbpasswd -a [USER]
```

Enter the password when prompted and update the configuration:

```bash
sudo nano /etc/samba/smb.conf
```

Restart and test the service:

```bash
# Restart Samba
sudo systemctl restart smbd

# Enable on boot
sudo systemctl enable smbd

# Check it is listening
sudo ss -tlnp | grep 445
```

## 3. Configuration & Workarounds

### Android Client Issues

> [!NOTE]
> If an Android File Manager refuses to show any files, it's because SMB encryption needs to be enabled globally.

### Windows Metadata

> [!NOTE]
> These commands may help Windows clients if metadata is not being served:
> 
> ```ini
> store dos attributes = yes # For xattrs
> ea support = yes # For xattrs
> vfs objects = streams_xattr # not supported on FUSE-mounted NTFS
> ```

### Tailscale Integration

Tailscale's dynamically generated interfaces can cause conflicts; adding `tailscale0` to your Samba configuration may not work. Verify by running:

```bash
sudo ss -tlnp | grep 445
```

If the Tailscale IP is not listed, run:

```bash
tailscale serve --bg --tcp 445 tcp://localhost:445
```

> [!WARNING]
> **Tailscale Serve**: Using `tailscale serve` often intercepts traffic *before* UFW block rules on that specific port. However, with strict ACLs, this is acceptable.

### Docker Healthcheck Issue

> [!WARNING]
> The `dperson/samba` image defines a `HEALTHCHECK` that fails by default because it connects as a guest without encryption. This may cause the container to be reported as "unhealthy".

## 4. Security

### Firewall Rules

Allow traffic on the following ports for the LAN subnet:

```bash
sudo ufw allow from [LAN-SUBNET] to any port 137,138,139,445 proto tcp
sudo ufw allow from [LAN-SUBNET] to any port 137,138 proto udp
```

For other subnets (e.g., VPNs):
- `[VPN-SUBNET-1]` (ASUS InstantGuard)
- `[VPN-SUBNET-2]` (OpenVPN)
- `[VPN-SUBNET-3]` (WireGuard)

### Hardening

Ensure encryption is enforced in `smb.conf`:

```ini
smb encrypt = required
```

Run this to confirm:

```bash
smbstatus -S
```

Restrict interfaces in `smb.conf`:

```ini
interfaces = [LAN-SUBNET]
bind interfaces only = yes
```

Additional UFW hardening:

```bash
sudo ufw deny in on eth0 to any port 139,445
```

### Entrypoint Script Workaround

To avoid plaintext secrets in Docker, utilise a mounted entrypoint script:

```bash
#!/bin/sh
password=$(tr -d '\n' < /run/secrets/password_standard)
exec samba.sh -u "[USER];$password" -s "public;/shares;yes;no;no;[USER]"
```

Ensure it is executable:

```bash
chmod +x /srv/samba/entrypoint.sh
```

## 5. Verification

### LAN-Only Access Test

1. From a device **not on your LAN or VPN** (e.g., cellular tether), run:
   
   ```bash
   nmap -p 445 [PUBLIC-IP]
   ```
   
   It should timeout or report as filtered.

2. From a device **on your VPN**, connect to the host's LAN IP:
   
   ```bash
   smbclient -L [HOST-IP]
   ```
