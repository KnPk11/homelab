# OpenClaw: Proxmox VM Spec

> [!NOTE]
> #Proxmox #VM #Infrastructure #OpenClaw #AI

This document details the specific Proxmox Virtual Machine (QEMU VM 103) configuration for the OpenClaw service (`lab-vm`).

## Provisioning Details

- **Guest Type**: Proxmox QEMU VM
- **OS Type**: Linux 6.x / Debian 13 (64-bit)
- **QEMU Guest Agent**: ✅ Enabled

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| VMID | 103 |
| VM Name | `lab-vm` |
| OS Type | Linux (`l26`) |
| CPU Cores | 4 cores (`cpu: host`) |
| RAM | 4096 MB (4 GB, Ballooning: 2048 MB) |
| Disk | 32 GB SSD (`virtio-scsi-single`, IOThread, Discard) |
| Storage Pool | `local-lvm` |
| QEMU Agent | Enabled |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.91/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (VirtIO)
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create VM**: Follow the standard Proxmox VM creation wizard or execute via CLI on the Proxmox host:
   ```bash
   qm create 103 \
     --name lab-vm \
     --ostype l26 \
     --cores 4 \
     --cpu host \
     --memory 4096 \
     --balloon 2048 \
     --scsihw virtio-scsi-single \
     --scsi0 local-lvm:32,discard=on,iothread=1,ssd=1 \
     --net0 virtio,bridge=vmbr0,firewall=1 \
     --agent 1 \
     --onboot 1
   ```
2. **Install OS**: Install Debian 13 / Linux server ISO.
3. **Guest Agent**: Ensure `qemu-guest-agent` is installed and running inside the VM (`systemctl enable --now qemu-guest-agent`).
