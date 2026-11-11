# lab-vm: Proxmox VM Spec

> [!NOTE]
> #Proxmox #VM #Infrastructure #LabVM #AI #Development

This document details the specific Proxmox Virtual Machine (QEMU VM 103) configuration for the application, developer, and AI agent workload host (`lab-vm`).

## Provisioning Details

- **Guest Type**: Proxmox QEMU VM
- **VMID**: `103`
- **OS Type**: Linux 6.x / Debian 13 (`l26`)
- **QEMU Guest Agent**: ✅ Enabled

### Resource Allocation

| Setting | Value |
| :--- | :--- |
| VMID | 103 |
| VM Name | `lab-vm` |
| OS Type | Linux (`l26`) |
| CPU Cores | 4 cores (`cpu: host`) |
| RAM | 6144 MB (6 GB, Ballooning: 4096 MB) |
| Root Disk (`scsi0`) | 64 GB SSD (`local-lvm`, discard=on, iothread=1, ssd=1) |
| Storage Pool | `local-lvm` |
| SCSI Controller | `virtio-scsi-single` |
| QEMU Agent | Enabled |

### Network Configuration

- **IPv4/CIDR**: `192.168.50.91/24` (Static)
- **Gateway**: `192.168.50.1`
- **Bridge**: `vmbr0` (VirtIO)
- **Firewall**: ✅ Enabled

## Setup Steps

1. **Create VM**: Execute via CLI on the Proxmox host:
   ```bash
   qm create 103 \
     --name lab-vm \
     --ostype l26 \
     --cores 4 \
     --cpu host \
     --memory 6144 \
     --balloon 4096 \
     --scsihw virtio-scsi-single \
     --scsi0 local-lvm:64,discard=on,iothread=1,ssd=1 \
     --net0 virtio,bridge=vmbr0,firewall=1 \
     --agent 1 \
     --onboot 1
   ```
2. **Install OS**: Install Debian 13 standard server.
3. **Guest Agent**: Ensure `qemu-guest-agent` is installed and running (`systemctl enable --now qemu-guest-agent`).
4. **GitOps Runbook**: Proceed to [lab-vm Deployment Guide](../../../../nodes/lab-vm/deployment.md).
