# Resources Reference

> [!NOTE]
> **Tags:** #Linux #CheatSheet #Docker #Backups #Networking #Resources

## 1. Description

A centralised reference for common Linux commands, Docker management, backup procedures, and essential external documentation links used in the homelab.

## 2. Quick Links

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Proxmox VE Helper Scripts](https://tteck.github.io/Proxmox/)
- [Docker Documentation](https://docs.docker.com/)
- [Self-Hosted Search Engine](https://selfh.st/apps/)
- [Linux Command Line Cheat Sheet](https://cheatography.com/davechild/cheat-sheets/linux-command-line/)
- [MikroTik RouterOS Documentation](https://help.mikrotik.com/docs/display/ROS/RouterOS)

## 3. System & Service Management

### Basic Commands
```bash
apt update && apt upgrade                    # Update package list and installed packages
apt dist-upgrade                             # Perform a distribution upgrade
systemctl restart lightdm                    # Restart desktop manager
shutdown -h now                              # Shut down
```

### Service Control
```bash
systemctl start [SERVICE]                    # Start a service
systemctl stop [SERVICE]                     # Stop a service
systemctl restart [SERVICE]                  # Restart a service
systemctl status [SERVICE]                   # Check service status
```

## 4. Network Information

```bash
ip addr show                                 # Show IP addresses of all network interfaces
hostname -I                                  # Display system IP addresses
ip route show                                # Display the routing table

# Check listening ports and sockets
ss -tunlp                                    # Show all TCP/UDP sockets and listening ports
lsof -i :[PORT]                              # Identify what is using a specific port
```

## 5. Disk & Filesystem Operations

### Disk Usage
```bash
lsblk                                      # List block devices and mount points
df -h                                      # Display disk space usage
du -sh /mnt/pool                           # Check size of a specific folder
du -h --max-depth=1                        # Check size of subdirectories
```

### File Operations
```bash
# Prepare directories
mkdir -p /home/[USER]/config

# Change ownership
chown -R $(id -u):$(id -g) /home/[USER]/[DIR]

# Generate random passwords
pwgen -s 20 1                                # Generate one secure, 20-character password

# Search for a file system-wide
find / -type f -name "config.yml" 2>/dev/null

# Safely unmount a device
umount /dev/[DEVICE]
```

## 6. User & Group Management

```bash
id                                          # Display user and group ID for current user
groups                                      # List groups the current user belongs to
```

## 7. Process Management

```bash
ps aux | grep [PROCESS]                     # Search for running processes by name
top                                         # Real-time system resource usage
kill -9 [PID]                               # Terminate a process by ID
```

## 8. Firewall (UFW & Iptables)

### UFW Commands
```bash
ufw allow [PORT]                            # Allow traffic on a specific port
ufw deny [PORT]                             # Deny traffic on a specific port
ufw status numbered                         # Show numbered list of rules
```

### Iptables
```bash
iptables -L INPUT --line-numbers             # List INPUT rules with numbers
iptables -D INPUT [RULE-NUMBER]              # Delete a rule by number
```

## 9. Data Sync (Rsync)

```bash
# Push data from one machine to another
rsync -avz /data/ [USER]@[REMOTE-IP]:/data
```

## 10. Security & Privacy

### Hashing
```bash
# Hash a password via shell
read -s -p "Enter password: " pass; echo -n "$pass" | sha256sum

# Hash a password via Caddy
caddy hash-password --plaintext "[PASSWORD]"
```

### Privacy
```bash
# View command history
history

# Delete specific history entries
for i in {1..3}; do history -d $(history 1 | awk '{print $1}'); done
```

## 11. Docker Management

### Container Operations
```bash
docker ps                                    # List running containers
docker logs [CONTAINER]                      # View container logs
docker start [CONTAINER]                     # Start a container
docker stop [CONTAINER]                      # Stop a container
docker restart [CONTAINER]                   # Restart a container
docker exec -it [CONTAINER] bash             # Open an interactive shell in a container
```

### Maintenance
```bash
# Copy files out of a container
docker cp [CONTAINER]:[PATH] [DESTINATION]

# Build a custom image
docker build --no-cache -t [IMAGE-NAME]:latest .

# Stop Docker engine
systemctl stop docker
```

## 12. Performance Tuning

Optimise kernel cache behaviour by adjusting `vm.swappiness` and `vfs_cache_pressure`:

```bash
# Recommended adjustments for servers
sysctl vm.swappiness=10                      # Reduce swap usage
sysctl vm.vfs_cache_pressure=2000            # Keep directory caches longer

# Make permanent (add to /etc/sysctl.conf):
echo "vm.swappiness=10" | tee -a /etc/etc/sysctl.conf
echo "vm.vfs_cache_pressure=2000" | tee -a /etc/etc/sysctl.conf
```

## 13. Backup Operations (Kopia)

Current standard for homelab backups.

```bash
# Create a snapshot
kopia snapshot create /data/path

# List snapshots for a specific source
kopia snapshot list /data/path

# Mount the repository for browsing
kopia repository connect filesystem --path [REPO-PATH]

# Restore a snapshot to a target directory
kopia snapshot restore [SNAPSHOT-ID] [DESTINATION]
```

## 14. Advanced Migration Guides

### Migrating Docker Volumes

#### Method 1: Direct Rsync
1. **Prepare Volume**:
   ```bash
   mkdir -p /var/lib/docker/volumes/[VOLUME-NAME]/_data
   ```
2. **Sync Data**:
   ```bash
   rsync -aHAX --numeric-ids /home/[USER]/[SOURCE]/ /var/lib/docker/volumes/[VOLUME-NAME]/_data/
   ```

#### Method 2: Tar Archive
1. **Extract from Archive**:
   ```bash
   tar -xvzf [ARCHIVE].tar.gz -C /var/lib/docker/volumes/[VOLUME-NAME]/_data
   ```

#### Method 3: Network Sync
1. **Transfer to Remote**:
   ```bash
   rsync -avh /var/lib/docker/volumes/[VOLUME-NAME]/ [USER]@[REMOTE-IP]:/tmp
   ```
2. **Move to Target**:
   ```bash
   cp -r /tmp/_data/* /var/lib/docker/volumes/[VOLUME-NAME]/_data/
   rm -rf /tmp/_data/
   ```

### Sharing via NFS
1. **Server Setup**:
   ```bash
   apt install nfs-kernel-server
   echo "/mnt/pool [LAN-SUBNET](rw,sync,no_subtree_check)" | tee -a /etc/exports
   exportfs -a
   systemctl restart nfs-kernel-server
   ```
2. **Client Mount**:
   ```bash
   mkdir -p /mnt/pool
   mount -t nfs [HOST-IP]:/mnt/pool /mnt/pool
   ```
