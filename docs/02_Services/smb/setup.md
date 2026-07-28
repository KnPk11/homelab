# SMB Setup

> [!NOTE]
> #SMB #Samba #Files #LAN #Networking #DockerCompose

## 1. Description

SMB/Samba file shares for Windows-friendly access to lab storage from PCs and VPN clients, with authenticated share access on the LAN.

Firewall, encryption, and credential handling: [security.md](security.md).

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

## 4. Verification

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
