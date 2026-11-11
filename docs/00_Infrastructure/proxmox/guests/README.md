# Proxmox Guest Allocation Matrix

> [!NOTE]
> #Proxmox #Infrastructure #Hardware #Virtualization #Inventory

This directory contains the authoritative hardware provisioning and resource allocation specifications for all virtualised guests (VMs and LXC containers) hosted on the Proxmox VE hypervisor (`proxmox-host`, `192.168.50.100`).

---

## 1. Virtual Machines (KVM / QEMU)

| VMID | Hostname | IP Address | Cores | RAM (Balloon) | Disks | Primary Workload | Hardware Spec |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **100** | `docker-services` | `192.168.50.95` | 8 | 8 GB (6 GB) | 40 GB + 100 GB SSD | Docker Stacks & Portainer | [docker-services.md](docker-services.md) |
| **101** | `nas` | `192.168.50.90` | 2 | 2 GB (1 GB) | 16 GB + 200 GB SSD | OpenMediaVault Storage | [nas.md](nas.md) |
| **103** | `lab-vm` | `192.168.50.91` | 4 | 6 GB (4 GB) | 64 GB SSD | Agent Workloads & Paperclip | [lab-vm.md](lab-vm.md) |

---

## 2. LXC Containers

| CTID | Hostname | IP Address | Cores | RAM (Swap) | Rootfs (+ Mounts) | Primary Workload | Hardware Spec |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **104** | `reverse-proxy` | `192.168.50.101` | 2 | 1 GB (1 GB) | 16 GB (+ 10 GB logs) | Caddy & Security Ingress | [reverse-proxy.md](reverse-proxy.md) |
| **105** | `ai-tools` | `192.168.50.105` | 4 | 2 GB (2 GB) | 16 GB SSD | AI Tools & Dev Environment | [ai-tools.md](ai-tools.md) |
| **106** | `dns` | `192.168.50.102` | 1 | 256 MB (256 MB) | 8 GB SSD | AdGuard Home DNS Resolver | [dns.md](dns.md) |
| **107** | `pulse` | `192.168.50.88` | 2 | 1 GB (512 MB) | 8 GB SSD | Pulse Monitoring Daemon | [pulse.md](pulse.md) |
| **108** | `vpns` | `192.168.50.87` | 1 | 1 GB (1 GB) | 8 GB SSD | Tailscale / WireGuard Routers | [vpns.md](vpns.md) |
| **109** | `pbs` | `192.168.50.86` | 4 | 2 GB (2 GB) | 8 GB (+ datastores) | Proxmox Backup Server | [pbs.md](pbs.md) |
| **110** | `k8s` | `192.168.50.96` | 2 | 2 GB (2 GB) | 16 GB SSD | Lightweight k3s Kubernetes | [k8s.md](k8s.md) |
| **111** | `syslog` | `192.168.50.89` | 1 | 1 GB (512 MB) | 8 GB (+ 4 GB logs) | Centralised Syslog / Loki | [syslog.md](syslog.md) |
| **112** | `ops` | `192.168.50.112` | 1 | 512 MB (512 MB) | 4 GB SSD | Automation & DDNS Plane | [ops.md](ops.md) |

> [!TIP]
> **LXC Provisioning Defaults**:
> - **SSH Public Keys**: All container creation commands include `--ssh-public-keys /root/.ssh/authorized_keys` to automatically propagate the hypervisor's management keys into `/root/.ssh/authorized_keys` inside the newly spawned container for immediate passwordless SSH access.
> - **Filesystem ACLs**: Standard POSIX ACLs (`acl=1`) are enabled by default on all ext4 and ZFS storage pools (`local-lvm`, `local-zfs`).

> [!NOTE]
> **Fleet DNS Architecture (Why not the router `192.168.50.1`?):**
> 1. **Firewall Isolation:** Pointing containers to the MikroTik edge router (`192.168.50.1:53`) directs traffic into the router's restricted `input` firewall chain. Using internal AdGuard keeps query traffic inside the LAN switching fabric.
> 2. **Local Name Resolution:** AdGuard Home (`192.168.50.102`) resolves private homelab split-DNS records and local rewrites, which edge router WAN forwarders cannot resolve.
> 3. **High Availability Fallback:** Workload guests configure both `192.168.50.102` (Primary) and `1.1.1.1` (Secondary) so outbound resolution survives AdGuard container restarts or maintenance.
> 4. **Loop Prevention:** CT 106 (`dns`) intentionally uses public upstreams (`1.1.1.1`, `9.9.9.9`) to prevent recursive lookup deadlocks.

---

## 3. Related Documentation

- **Base Provisioning Templates:**
  - [Debian VM Creation Guide](../provisioning/debian-vm.md)
  - [Debian LXC Creation Guide](../provisioning/debian-lxc.md)
- **Universal Node Bootstrap:** [universal-node-bootstrap.md](../../universal-node-bootstrap.md)
- **Hypervisor Inventory:** [inventory.md](../inventory.md)
