# SMB Security

> [!NOTE]
> #SMB #Samba #Security #Firewall #Networking

Firewall rules, encryption, and secret handling for Samba. Install and workarounds live in [setup.md](setup.md).

## 1. Description

SMB should only be reachable from trusted LANs and VPN ranges, with encryption required and credentials kept out of compose environment variables.

## 2. Firewall Rules

Allow traffic on the following ports for the LAN subnet:

```bash
sudo ufw allow from [LAN-SUBNET] to any port 137,138,139,445 proto tcp
sudo ufw allow from [LAN-SUBNET] to any port 137,138 proto udp
```

For other subnets (e.g., VPNs):

- `[VPN-SUBNET-1]` (ASUS InstantGuard)
- `[VPN-SUBNET-2]` (OpenVPN)
- `[VPN-SUBNET-3]` (WireGuard)

Additional UFW hardening:

```bash
sudo ufw deny in on eth0 to any port 139,445
```

## 3. Hardening

Ensure encryption is enforced in `smb.conf`:

```ini
smb encrypt = required
```

Confirm:

```bash
smbstatus -S
```

Restrict interfaces in `smb.conf`:

```ini
interfaces = [LAN-SUBNET]
bind interfaces only = yes
```

## 4. Entrypoint Script Workaround

To avoid plaintext secrets in Docker, utilise a mounted entrypoint script:

```bash
#!/bin/sh
password=$(tr -d '\n' < /run/secrets/password_standard)
exec samba.sh -u "[USER];$password" -s "public;/shares;yes;no;no;[USER]"
```

Ensure it is executable:

```bash
chmod +x /srv/samba/entrypoint.sh
```
