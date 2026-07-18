# Syncthing Setup

> [!NOTE]
> **Tags:** #Syncthing #Sync #P2p #Backup

## 1. Description

Peer-to-peer file synchronisation across multiple devices.

## 2. Installation

### Option A: Bare-Metal (Recommended for AI-Tools / Management Nodes)

This installs Syncthing directly on the host OS as a system service.

```bash
# 1. Install via apt
sudo apt-get update && sudo apt-get install syncthing -y

# 2. Create a dedicated service user
sudo useradd -r -s /usr/sbin/nologin -d /var/lib/syncthing -m syncthing

# 3. Enable the service for the syncthing user
sudo systemctl enable --now syncthing@syncthing.service

# 4. Expose the Web GUI
# Edit /var/lib/syncthing/.local/state/syncthing/config.xml and change the GUI address to 0.0.0.0:8384
# Restart the service: sudo systemctl restart syncthing@syncthing.service
```

#### Directory Permissions

Since Syncthing runs as a non-root user, the synced directories must be owned by the `syncthing` user. Furthermore, if you edit files as `root` (or another user), those new files might be created with permissions that block Syncthing from updating them later.

To prevent this, we use Access Control Lists (ACLs) to ensure the `syncthing` user always retains read, write, and execute permissions on all newly created files and directories.

```bash
# 1. Install ACL package (if on Debian/Ubuntu)
sudo apt-get install acl -y

# 2. Set base ownership to syncthing
chown -R syncthing:syncthing /opt/dev/projects /opt/dev/docs_private

# 3. Apply ACLs to existing files and set default ACLs for future files
setfacl -R -m u:syncthing:rwx /opt/dev/projects /opt/dev/docs_private
setfacl -R -d -m u:syncthing:rwx /opt/dev/projects /opt/dev/docs_private
```

### Option B: Docker Compose (Legacy / General Use)

1. Add the Docker Compose stack to Portainer and start it.

## 3. Network Connectivity

For Syncthing devices to find each other and sync across different networks, you must ensure at least one of the following connection methods is available:
1. **Port Forwarding (Recommended)**: Log into your internet router and forward **TCP and UDP port 22000** to the Syncthing host's internal IP. This allows fast, direct peer-to-peer connections.
2. **Relays (Fallback)**: If port forwarding isn't possible (e.g., you are behind a strict NAT or cellular network), ensure "Enable Relays" is checked in Syncthing's GUI (`Actions -> Settings -> Connections`). This securely bridges the connection through a community server via outbound traffic.

## 4. Security

- **GUI Authentication**: It is imperative to enable GUI authentication. On your first login via the Web UI, go to `Actions -> Settings -> GUI` and establish a username and strong password.
- **Service User**: Syncthing runs as a dedicated non-privileged `syncthing` user. This limits the blast radius if the service is compromised, while root retains full access to all synced directories.
- **Listen Address & Firewall**: The GUI address can safely be bound to all interfaces (`0.0.0.0:8384`) instead of a specific IP, provided that a strict host-level firewall (like Proxmox Firewall) blocks direct access to the port and only permits traffic from your reverse proxy.
- **Traffic Encryption**: Syncthing encrypts all peer-to-peer traffic by default.
- **Relays vs Port Forwarding**: Relayed traffic is fully end-to-end encrypted. However, setting up a port forward (TCP/UDP 22000) allows for direct, point-to-point connections. These are drastically faster and provide enhanced privacy by preventing third-party relay operators from seeing connection metadata (IP addresses and transfer volumes).
- **Untrusted Devices**: Utilise the "Untrusted" folder setting for end-to-end encrypted folders. This ensures data is stored encrypted on the remote device's disk and only decrypted by Syncthing at runtime. This is ideal for syncing to untrusted devices or cloud storage.
