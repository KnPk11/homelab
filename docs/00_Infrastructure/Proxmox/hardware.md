> [!NOTE]
> **Tags:** #Proxmox #Infrastructure #Hardware #Storage #Networking

# Proxmox Hardware Management & Troubleshooting

## Drive Management

### Thin Provisioning Strategy

When using thin-provisioned storage pools (LVM-Thin or ZFS), you can safely over-allocate VM disk space. Proxmox only consumes physical space as data is actually written.

#### Maintaining Efficiency (Reclaiming Space)
To ensure deleted files inside a VM actually free up space on the Proxmox host:

1.  **Discard Flag**: Ensure the **Discard** checkbox is enabled in the VM's **Hardware** → **Hard Disk** settings in Proxmox.
2.  **fstrim**: Enable the periodic TRIM service inside the VM to notify Proxmox of deleted blocks.
    - **Applicability**: Only applicable to **VMs**.
    - **LXCs**: Not needed; the Proxmox host manages the filesystem for LXCs and handles TRIM globally.

**Enable on Linux VMs:**
```bash
sudo systemctl enable --now fstrim.timer
```

---

### Enlarging a VM Drive

#### Step 1: Expand Disk in Proxmox
1. Log into the **Proxmox Web Interface**.
2. Navigate to your **VM** → **Hardware** tab.
3. Select the target **Hard Disk** and choose **Resize** from **Disk Action**.
4. Specify the **Size Increment**.

#### Step 2: Address Swap Partition Conflict
The swap partition often blocks new space. Temporarily remove and recreate it:

```bash
# Disable swap
sudo swapoff -a

# Open partition editor (replace [DEVICE] with your device, e.g., sda)
sudo cfdisk /dev/[DEVICE]
```

**In cfdisk:**
- Delete the existing swap partition.
- Resize the main partition (leave 2-4GB free at the end).
- Create a new swap partition in the free space.
- Choose **Type** → `82: Linux swap`.
- Write changes and quit.

#### Step 3: Refresh Partition Table
```bash
sudo partprobe /dev/[DEVICE]
```

#### Step 4: Expand Filesystem
Grow the filesystem to fill the new partition space:

```bash
# For EXT4 (Debian default)
sudo resize2fs /dev/[PARTITION]
```

#### Step 5: Reconfigure Swap
1. Enable the swap partition:
```bash
sudo mkswap /dev/[SWAP-PARTITION]
```
2. Get the new swap UUID:
```bash
lsblk -no UUID /dev/[SWAP-PARTITION]
```
3. Update `/etc/fstab`:
```bash
sudo nano /etc/fstab
```
Replace the old swap UUID with the new one `[DISK-UUID]`.

4. Update boot image:
```bash
sudo update-initramfs -u -k all
```

#### Step 6: Verify
```bash
# Confirm new size
df -h
# Verify swap is active
sudo swapon --show
```

---

## Proxmox NIC Hang (Intel i219-V / Realtek)

Common on Lenovo Tiny units and other mini-PCs. The network link drops under heavy load, showing `Detected Hardware Unit Hang` in `dmesg`.

### Symptoms

The classic "NIC hang" manifests as:

- `dmesg` shows: `e1000e: Detected Hardware Unit Hang`
- Network link drops under heavy load
- Requires physical cable reset to recover

> **Root Cause:** In 90% of Intel e1000e hang cases on Proxmox/Mini-PCs, the issue is the card overwhelming the buffer. Throttling the interrupt rate usually stops the hanging without sacrificing much performance.

### Immediate Fix
Disable problematic offload features:

```bash
ethtool -K [NIC] tso off gso off
```

### Permanent Fix
Add the following `post-up` commands to your `/etc/network/interfaces` file:

```cfg
auto vmbr0
iface vmbr0 inet static
        address [IP]/24
        gateway [GATEWAY]
        bridge-ports [NIC]
        bridge-stp off
        bridge-fd 0
        # Fixes software offloading hangs
        post-up /usr/sbin/ethtool -K [NIC] tso off gso off gro off
        # Fixes hardware "sleep" hangs
        post-up /usr/sbin/ethtool --set-eee [NIC] eee off
```

### Auto-Heal Script
Create a script to automatically recover the interface if a ping to the router fails.

1. **Create Script**: `nano /usr/local/bin/fix-network.sh`
```bash
#!/bin/bash

ROUTER_IP="[GATEWAY]"
INTERFACE="[NIC]"

# Check if the Router's MAC address is visible in the ARP table
if ! ip neigh show $ROUTER_IP | grep -qE "REACHABLE|DELAY|STALE"; then
    echo "$(date): ARP check failed. NIC $INTERFACE likely hung." >> /var/log/network-repair.log
    /usr/sbin/ip link set $INTERFACE down
    sleep 3
    /usr/sbin/ip link set $INTERFACE up
fi
```

2. **Make Executable**: `chmod +x /usr/local/bin/fix-network.sh`

3. **Schedule via Crontab**: `*/2 * * * * /usr/local/bin/fix-network.sh`

### Verification & Testing

> [!IMPORTANT]
> Always verify the script's logic before scheduling it to avoid accidental network lockouts.

#### 1. Test the Logic (Dry Run)
Ensure the script correctly identifies the current network state as **UP**:

```bash
ROUTER_IP="[GATEWAY]"

if ip neigh show $ROUTER_IP | grep -qE "REACHABLE|DELAY|STALE"; then
    echo "Network looks GOOD — Script would do nothing."
else
    echo "Network looks BAD — Script would RESTART [NIC]."
fi
```
- **Success**: Output says "Network looks GOOD".
- **Failure**: If it says "BAD", check your gateway IP and ARP table visibility before proceeding.

#### 2. Test the Action (Real Test)
Verify that Proxmox can successfully toggle the interface and recover. Your SSH session will freeze for 2–5 seconds. **Do not close the window.**

```bash
ip link set [NIC] down && sleep 2 && ip link set [NIC] up
```
- **Success**: Terminal hangs briefly, then reconnects.
- **Failure**: Connection does not return; physical cable reset required.

#### 3. Full Simulation
To verify the auto-heal trigger works when the network is actually "lost":

1. **Edit Script**: `nano /usr/local/bin/fix-network.sh`
2. **Change IP**: Set `ROUTER_IP` to a fake IP (e.g., `[IP].254`).
3. **Run Manually**:
   ```bash
   bash /usr/local/bin/fix-network.sh
   ```
4. **Check Logs**:
   ```bash
   cat /var/log/network-repair.log
   ```

> [!SUCCESS]
> The log should show an entry stating the ARP check failed and the NIC was restarted.
