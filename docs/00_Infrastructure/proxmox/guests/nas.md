# nas: Proxmox VM Spec

> [!NOTE]
> #Proxmox #VM #Infrastructure #NAS #OMV #Storage

This document details the specific Proxmox Virtual Machine (QEMU VM 101) configuration for OpenMediaVault / Network Attached Storage (`nas`).

## Provisioning Details

- **Guest Type**: Proxmox QEMU VM
- **VMID**: `101`
- **OS Type**: Linux 6.x / Debian 13 (`l26`)
- **QEMU Guest Agent**: ✅ Enabled

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| VMID | 101 |
| VM Name | `nas` |
| OS Type | Linux (`l26`) |
| CPU Cores | 2 cores (`cpu: host`) |
| RAM | 2048 MB (2 GB, Ballooning: 1024 MB) |
| OS Disk (`scsi0`) | 16 GB SSD (`local-lvm`, discard=on, iothread=1, ssd=1) |
| Data Disk (`scsi1`) | 200 GB SSD (`local-lvm`, backup=0, discard=on, iothread=1, ssd=1) |
| Storage Pool | `local-lvm` |
| SCSI Controller | `virtio-scsi-single` |
| QEMU Agent | Enabled |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.90/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (VirtIO)
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create VM**: Execute via CLI on the Proxmox host:
   ```bash
   qm create 101 \
     --name nas \
     --ostype l26 \
     --cores 2 \
     --cpu host \
     --memory 2048 \
     --balloon 1024 \
     --scsihw virtio-scsi-single \
     --scsi0 local-lvm:16,discard=on,iothread=1,ssd=1 \
     --scsi1 local-lvm:200,backup=0,discard=on,iothread=1,ssd=1 \
     --net0 virtio,bridge=vmbr0,firewall=1 \
     --agent 1 \
     --onboot 1
   ```
2. **Install OS**: Install Debian standard server and overlay OpenMediaVault.
3. **Guest Agent**: Ensure `qemu-guest-agent` is installed and running (`systemctl enable --now qemu-guest-agent`).
4. **GitOps Runbook**: Proceed to [nas Deployment Guide](../../../../nodes/nas/deployment.md).
