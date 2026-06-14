# Syncthing Setup

> [!NOTE]
> **Tags:** #Syncthing #Sync #P2p #Backup

## 1. Description

Peer-to-peer file synchronisation across multiple devices.

## 2. Installation

1. Add the Docker Compose stack to Portainer and start it.

## 3. Security

- **GUI Authentication**: Ensure GUI authentication is enabled. Alternatively, restrict Syncthing's listening interface to the local subnet.
- **Traffic Encryption**: Syncthing encrypts all traffic by default.
- **Untrusted Devices**: Utilise the "Untrusted" folder setting for end-to-end encrypted folders. This ensures data is stored encrypted on the remote device's disk and only decrypted by Syncthing at runtime. This is ideal for syncing to untrusted devices or cloud storage.
