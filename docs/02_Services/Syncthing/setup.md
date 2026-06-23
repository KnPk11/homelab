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

# 2. Enable the service for the desired user (e.g., root)
sudo systemctl enable --now syncthing@root.service

# 3. Expose the Web GUI
# Edit ~/.local/state/syncthing/config.xml and change the GUI address to 0.0.0.0:8384
# Restart the service: sudo systemctl restart syncthing@root.service
```

### Option B: Docker Compose (Legacy / General Use)

1. Add the Docker Compose stack to Portainer and start it.

## 3. Security

- **GUI Authentication**: It is imperative to enable GUI authentication. On your first login via the Web UI, go to `Actions -> Settings -> GUI` and establish a username and strong password.
- **Service User (Privileged Warning)**: The GUI will warn you against running Syncthing as a privileged user (`root`).
  - *LXC Containers*: In isolated, firewalled containers like management nodes (e.g., `ai-tools`), running as `root` is acceptable. It guarantees zero permission conflicts with files created by other `root` processes (like VS Code Remote). You can safely dismiss the GUI warning.
  - *Standard Servers*: On a standard host, you should create a dedicated, non-privileged `syncthing` user and configure POSIX ACLs or shared groups for the synced directories.
- **Listen Address & Firewall**: The GUI address can safely be bound to all interfaces (`0.0.0.0:8384`) instead of a specific IP, provided that a strict host-level firewall (like Proxmox Firewall) blocks direct access to the port and only permits traffic from your reverse proxy.
- **Traffic Encryption**: Syncthing encrypts all peer-to-peer traffic by default.
- **Untrusted Devices**: Utilise the "Untrusted" folder setting for end-to-end encrypted folders. This ensures data is stored encrypted on the remote device's disk and only decrypted by Syncthing at runtime. This is ideal for syncing to untrusted devices or cloud storage.
