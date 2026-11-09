# Intel TCO Hardware Watchdog on Proxmox VE

A guide to enabling and configuring the physical **Intel TCO (Total Cost of Ownership) Hardware Watchdog** (`iTCO_wdt`) on Intel-based Proxmox nodes (e.g. Lenovo ThinkCentre Tiny, Dell OptiPlex Micro, HP ProDesk Mini).

---

## 1. Overview & How It Works

A hardware watchdog is an autonomous hardware timer embedded directly inside the Intel chipset (PCH). 

* **The Heartbeat:** Once enabled, the operating system (via `systemd` or a watchdog daemon) must regularly send a "ping" (heartbeat) to `/dev/watchdog` (e.g. every 15–30 seconds).
* **The Safeguard:** If the Linux kernel encounters a hard panic, freeze, or deadlock, the heartbeat stops.
* **The Reset:** When the timer reaches zero, the Intel chipset physically pulls the motherboard's hardware reset line, forcing an immediate reboot without human intervention.

---

## 2. Why Proxmox Blacklists It by Default

In standard Proxmox VE installations, the Intel TCO watchdog modules are blacklisted in `/lib/modprobe.d/blacklist_proxmox-kernel-*.conf`:
```text
blacklist iTCO_vendor_support
blacklist iTCO_wdt
```
* **Reason:** In enterprise multi-node clusters with High Availability (HA), Proxmox uses its own fencing mechanism (`watchdog-mux` with `softdog` or IPMI). If multiple services contend for `/dev/watchdog` without coordination, unexpected resets can occur.
* **On a Standalone Homelab Node:** Enabling the physical hardware watchdog is safe and provides an automated self-healing reboot mechanism if the node ever locks up while you are away.

---

## 3. Step-by-Step Enablement Guide

### Step 1: Override the Kernel Blacklist
Create a module override configuration:
```bash
cat << 'EOF' > /etc/modprobe.d/watchdog.conf
# Enable physical Intel TCO Watchdog
softdep iTCO_wdt pre: iTCO_vendor_support
EOF
```

### Step 2: Ensure Modules Load on Boot
Add the modules to `/etc/modules`:
```bash
cat << 'EOF' >> /etc/modules
iTCO_vendor_support
iTCO_wdt
EOF
```

### Step 3: Load the Module Manually
```bash
modprobe iTCO_vendor_support
modprobe iTCO_wdt
```
Verify that `/dev/watchdog` has appeared:
```bash
ls -l /dev/watchdog*
# Expected: /dev/watchdog and /dev/watchdog0
```

### Step 4: Configure systemd to Manage the Heartbeat
Edit `/etc/systemd/system.conf`:
```ini
[Manager]
RuntimeWatchdogSec=30s
RebootWatchdogSec=5min
ShutdownWatchdogSec=10min
```
* `RuntimeWatchdogSec=30s`: systemd will ping `/dev/watchdog` every 15 seconds (half the timeout). If systemd freezes for 30 seconds, the Intel chipset forces a hard hardware reboot.
* `ShutdownWatchdogSec=10min`: Protects against the system hanging during reboot or shutdown (e.g. waiting for a hung network share or unmount).

Apply the configuration without rebooting:
```bash
systemctl daemon-reexec
```

Verify systemd has claimed the watchdog:
```bash
dmesg | grep -i watchdog
# Expected: systemd[1]: Using hardware watchdog 'iTCO_wdt', version 1, device /dev/watchdog0
```

---

## 4. Testing the Hardware Watchdog (Optional)

> [!CAUTION]
> This command triggers an intentional Linux kernel panic to simulate a hard system crash. Do not run this during active production workloads.

Enable SysRq and trigger a crash:
```bash
echo 1 > /proc/sys/kernel/sysrq
echo c > /proc/sysrq-trigger
```
* **Expected Result:** The kernel will panic, all heartbeats will cease, and within 30 seconds the Intel hardware watchdog will hard-reboot the machine automatically.
