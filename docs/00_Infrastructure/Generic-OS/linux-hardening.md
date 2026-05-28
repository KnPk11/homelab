> [!NOTE]
> **Tags:** #Linux #Security #Hardening

# Linux Hardening Guide

Guidelines and procedures for securing Linux-based systems in the homelab.

---

## System Access & Security

### SSH Hardening
If the system is exposed to the WAN, implement the following:
- Use passkey-encrypted SSH keys.
- **Disable password authentication** in `/etc/ssh/sshd_config`.
- Implement rate limiting:
```bash
sudo ufw limit ssh
```
- Consider changing the default port (e.g., to 2222).

### User Session Locking
Enable password-protected login and automatic session locking via system configuration (e.g., `raspi-config` on Raspberry Pi).

---

## Storage & Encryption

### Encrypted Partitions
> [!IMPORTANT]
> Since the SD card is typically unencrypted, use encrypted partitions for sensitive data like `srv` and `data`. This ensures that secrets are unloaded if the device is powered down or stolen.

---

## Password Management

### General Best Practices
- Never reuse passwords across different setups.
- Use **Vaultwarden** to generate and store secure passphrases.
- Enable **2FA/TOTP** where supported.

### Fail2Ban
Use `fail2ban` to protect against brute-force attacks on SSH and other exposed services.

---

## Network Security (Firewall)

### UFW Configuration
Ensure UFW is active and blocking non-essential traffic.

```bash
# Enable UFW and set default policies
sudo ufw default deny incoming
sudo ufw allow 80,443/tcp
sudo ufw allow in on tailscale0
sudo ufw enable
```

### IPv6 Considerations
Allow link-local traffic for local network discovery:
```bash
sudo ufw allow from fe80::/10
```

### Logging & Auditing
Enable UFW logging to monitor traffic:
```bash
sudo ufw logging on
# View logs
sudo tail -f /var/log/ufw.log
```

### Service-Specific Rules
Use specific IPs for sensitive services like Samba and subnet rules for discovery protocols (mDNS).
```bash
sudo ufw allow from 192.168.1.0/24 to any port 5353 proto udp
```

### External Auditing
Periodically audit firewall rules and scan from an external connection:
```bash
# Check status and policies
sudo ufw status verbose
# Audit numbered rules
sudo ufw status numbered
# External scan
nmap [DOMAIN]
```

---

## Advanced Traffic Control

### Rate Limiting (iptables)
Apply rate limiting to prevent flooding on common ports:

```bash
# Reject connections above limit
sudo iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 50 -j REJECT

# Hashlimit for HTTPS
sudo iptables -A INPUT -p tcp --dport 443 \
  -m conntrack --ctstate NEW \
  -m hashlimit --hashlimit 200/sec --hashlimit-burst 500 \
  --hashlimit-mode srcip --hashlimit-name https_limit \
  -j ACCEPT
```

> [!WARNING]
> Manual `iptables` rules may conflict with UFW or be lost after a reboot. Use `iptables-persistent` if these rules are required long-term.

---

## File System & Permissions

### Principle of Least Privilege
- Segregate configuration files containing secrets from general notes.
- Use environment variables for sensitive data.
- Ensure `.env` files and secrets have restrictive permissions (`chmod 600`).
- Avoid mounting the host root (`/`) or home directories into containers unless absolutely necessary.

### Restrictive Permissions Scripting
Use consistent ownership and permissions for sensitive directories (e.g., `certs`, `secrets`):

1. Set ownership:
```bash
sudo chown -R 1000:1000 /data/certs
sudo chown -R 1000:1000 /data/secrets
```

2. Restrict directory access:
```bash
chmod 700 /data/certs
chmod 700 /data/secrets
```

3. Restrict file access:
```bash
find /data/certs -type f -exec chmod 600 {} \;
find /data/secrets -type f -exec chmod 600 {} \;
```

---

## Monitoring & Health

### Drive Health (S.M.A.R.T.)
Install `smartmontools` to monitor drive health:
```bash
sudo apt install smartmontools
sudo smartctl -a -d sat /dev/sda
```

### Bad Block Detection
Perform read-only scans for bad blocks:
```bash
sudo badblocks -sv /dev/sda
```

### Log Monitoring
Check system logs for I/O errors:
```bash
dmesg | grep -i error
```

---

## VPN & Remote Access

### Secure Tunnels
Use **Tailscale**, **WireGuard**, or **OpenVPN** for remote access without opening public ports.

- **Kill Switch**: Ensure a kill switch is enabled to prevent traffic leaks if the VPN drops.
- **DNS Leak Testing**: Verify privacy using tools like `browserleaks.com/dns`.
