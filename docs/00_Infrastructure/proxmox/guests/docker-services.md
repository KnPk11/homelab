# docker-services: Proxmox VM Spec

> [!NOTE]
> #Proxmox #VM #Infrastructure #Docker #Linux

This document details the specific Proxmox Virtual Machine (QEMU VM 100) configuration for the primary Docker Host (`docker-services`).

## Provisioning Details

- **Guest Type**: Proxmox QEMU VM
- **VMID**: `100`
- **OS Type**: Linux 6.x / Debian 13 (`l26`)
- **QEMU Guest Agent**: ✅ Enabled

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| VMID | 100 |
| VM Name | `docker-services` |
| OS Type | Linux (`l26`) |
| CPU Cores | 8 cores (`cpu: host`) |
| RAM | 8192 MB (8 GB, Ballooning: 6144 MB) |
| Root Disk (`scsi0`) | 40 GB SSD (`local-lvm`, discard=on, iothread=1, ssd=1) |
| App Data Disk (`scsi1`) | 100 GB SSD (`local-lvm`, discard=on, iothread=1, ssd=1) |
| Storage Pool | `local-lvm` |
| SCSI Controller | `virtio-scsi-single` |
| QEMU Agent | Enabled |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.95/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (VirtIO)
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create VM**: Follow the standard Proxmox VM creation wizard or execute via CLI on the Proxmox host:
   ```bash
   qm create 100 \
     --name docker-services \
     --ostype l26 \
     --cores 8 \
     --cpu host \
     --memory 8192 \
     --balloon 6144 \
     --scsihw virtio-scsi-single \
     --scsi0 local-lvm:40,discard=on,iothread=1,ssd=1 \
     --scsi1 local-lvm:100,discard=on,iothread=1,ssd=1 \
     --net0 virtio,bridge=vmbr0,firewall=1 \
     --agent 1 \
     --onboot 1
   ```
2. **Install OS**: Install Debian 13 (Bookworm / Trixie) standard server.
3. **Guest Agent**: Ensure `qemu-guest-agent` is installed and running (`systemctl enable --now qemu-guest-agent`).
4. **GitOps Runbook**: Proceed to [docker-services Deployment Guide](../../../../nodes/docker-services/deployment.md).
