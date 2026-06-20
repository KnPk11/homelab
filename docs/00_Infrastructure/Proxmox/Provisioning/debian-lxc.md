> [!NOTE]
> **Tags:** #Proxmox #Infrastructure #Provisioning #Debian #Linux #LXC

# Debian LXC Provisioning Guide

This guide provides a standard blueprint for creating a Debian-based Linux Container (LXC) on Proxmox.

## Phase 1: LXC Creation

1. **Download Template**: Fetch the `Debian 13` template (or latest stable) in the Proxmox local storage.
2. **Configure General Settings**:
   - Enable **Unprivileged Container** and **Nesting**.
   - **Password**: Set a strong root password for the initial login.
   - **SSH Keys**: Highly recommended. Paste your public key for passwordless access.
3. **Resources**:
   - **Disk**: 8 GiB (Default ACLs).
   - **CPU**: 2 Cores.
   - **Memory**: 2048 MiB.
4. **Network**:
   - **IPv4/CIDR**: Assign a unique static IP (e.g., `[STATIC-IP]/24`).
   - **Gateway**: Your router's IP (e.g., `[GATEWAY-IP]`).
5. **DNS**: Leave as default unless a custom resolver is required.

## Phase 2: Initial OS Configuration

Update the system and install essential packages:

```bash
apt update && apt install sudo curl -y
```

Set up unattended upgrades to ensure the node stays secure.
