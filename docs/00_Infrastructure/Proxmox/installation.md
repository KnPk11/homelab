> [!NOTE]
> **Tags:** #Proxmox #Infrastructure #Setup #Security

# Proxmox VE Installation & Hardening

## Preparation & Boot

- **Download**: Get the latest [Proxmox VE ISO](https://www.proxmox.com/en/downloads) from the official website.
- **Flash**: Use Rufus to flash the ISO to a USB drive.
- **Secure Boot**: Disable secure boot in the BIOS for best compatibility.
- **Boot**: Insert the USB into the target machine and boot from it via the BIOS/UEFI boot menu.

---

## Installation Configuration

> [!WARNING]
> Long passphrases may cause issues when logging into the web GUI later. Keep it secure but manageable.

Follow the on-screen prompts to configure the base system:
- **Target Drive**: Select the target drive.
    - *Note*: `EXT4` is a standard, reliable choice for single-drive setups. Use ZFS if you plan on using RAID.
- **Location**: Set your Country, Time zone, and Keyboard Layout.
- **Credentials**:
    - **Password**: Set a strong root password.
    - **Email**: Enter a valid email address `[EMAIL]`.
	    - *Note*: This email is **not** used as a username but for system alerting (e.g., failed backups, system errors).
- **Network Configuration**:
    - **Hostname**: `pve1.[DOMAIN]` (e.g., `pve1.mylab.home`)
    - **IP Address**: Choose a static IP (e.g., `192.168.1.100`).
    - **Important**: Ensure your router’s DHCP reservation is set to this same static IP to avoid conflicts.

---

## First Login

Once the installation finishes, the system will reboot into a CLI login screen. You do not need to log in there.

1. Go to a different computer on the same network.
2. Open a browser and navigate to: `https://[PVE-IP]:8006`
    - *Note*: You may get an SSL warning; this is normal. Click **Advanced** → **Proceed**.
3. **Username**: `root`
4. **Password**: The password you set during installation.

---

## Post-Installation Setup

### 1. Run Optimization Scripts

Instead of manually editing repository files, use the community "Proxmox VE Post Install" script (often referred to as the tteck scripts) to configure the system for home use.

1. In the Proxmox Web GUI, click your node (e.g., `pve1`) on the left, then click **>_ Shell**.
2. Paste and run the Proxmox VE Post Install Script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

1. **Script prompts**:
    - **Use Correct Sources**: `Yes`
    - **Disable Enterprise Repository**: `Yes` (Removes the paid repo that causes errors).
    - **Add Ceph Package Sources**: `No` (Unless you specifically plan to use Ceph clustering).
    - **Enable No-Subscription Repository**: `Yes` (Adds the free community repo).
    - **Add Test Repository**: `No` (Keep stability; avoid beta updates).
    - **Disable Subscription Nag**: `Yes` (Removes the popup on login).
    - **Disable High Availability**: `Yes` (Saves resources for a single node set-up, can be enabled later).
    - **Disable Corosync for a Proxmox VE Cluster?**: `Yes` (Unless clustering).

### 2. Maintenance

- **Updates**: Periodically check for system updates.
    - *Navigate to*: `Datacenter` → `pve1` → `Updates` → click **Refresh** → click **Upgrade**.

### 3. Dark Theme

SSH and run this:

```bash
bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh) install
```

Refresh your browser afterwards.

> [!INFO]
> To uninstall the script:
> ```bash
> bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh) uninstall
> ```

---

## Architecture Decisions

### Docker Strategy: VM vs. LXC?

**Recommendation**: If you are new to Proxmox, start with a **Ubuntu Server VM**. It creates a standard environment where Docker works perfectly without needing to troubleshoot specific LXC nesting or storage driver issues.

| Feature | **Ubuntu Server VM** | **LXC Container** |
| :--- | :--- | :--- |
| **Isolation** | **High**: Full kernel isolation. Most secure. | **Medium**: Shares the host kernel (Proxmox). |
| **Overhead** | **Higher**: Allocates dedicated RAM/CPU. | **Lower**: Extremely lightweight and efficient. |
| **Docker Support** | **Native**: Just works exactly as expected. | **Complex**: Requires "Nesting" enabled; can have quirks. |
| **Portability** | **Easy**: Can easily migrate the VM to another host. | **Easy**: Proxmox backups make this simple. |

### VM Auto-Start

1. **Select the VM**: Click on your VM in the left sidebar.
2. **Go to Options**: In the middle menu, click the **Options** tab.
3. **Find "Start at boot"**: Look for the row that says **Start at boot**.
4. **Edit it**: Double-click that row, check the box, and click **OK**.

---

## Security & Hardening

### Access Control

- **Web UI 2FA**: Available but often unnecessary for homelabs if access is restricted to a trusted network.
- **SSH Rate Limiting**: Can be configured on the Proxmox host, but typically redundant if your firewall already blocks unauthorized access.
- **RBAC**: Proxmox supports granular user roles. Useful if multiple people access the environment.

### Network & Firewall

- **Separate Management VLAN**: Isolate the Proxmox management interface from VMs. This adds a layer of protection.
- **Host Firewall**: Proxmox includes a built-in firewall. This is optional if your router already handles network-level filtering.

### Backup Encryption

> [!WARNING]
> Debian does **not** enable full-disk encryption by default. Unencrypted backups could expose VM disk contents if an external drive is stolen.

- **Encrypted Backups**: Proxmox supports backup encryption via the `--encryption` flag with `vzdump` or configuring encryption keys.
- **VM Encryption**: Use LUKS encryption inside individual VMs for sensitive data rather than encrypting the entire host. This keeps the host recoverable without complex boot-time decryption.

> [!TIP]
> Consider setting up **Proxmox Backup Server (PBS)** for incremental, deduplicated, and highly efficient backups across your entire cluster.

### Summary of Security Priorities

| Priority        | Item                                                  |
| :-------------- | :---------------------------------------------------- |
| **Recommended** | Unattended updates, RBAC, login monitoring            |
| **Optional**    | Separate VLAN, host firewall, 2FA, SSH rate limiting  |
| **Advanced**    | Backup encryption, VM encryption (LUKS/Dropbear/Tang) |

---

## Troubleshooting

### Docker Port Bind Issue

If Docker starts too quickly before internal IPs are assigned, it may fail to bind ports.

1. **Create Wait Script**: `sudo nano /data/scripts/Utilities/wait_for_network.sh`

```bash
#!/bin/bash
while ! ip addr show ens18 | grep -q "[IP]"; do
    sleep 1
done
```

2. **Make Executable**: `sudo chmod +x /data/scripts/Utilities/wait_for_network.sh`

3. **Edit Docker Service**: `sudo systemctl edit docker.service`

```ini
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
ExecStartPre=/data/scripts/Utilities/wait_for_network.sh
```

4. **Reload & Reboot**:
```bash
sudo systemctl daemon-reload
sudo reboot
```
