> [!NOTE]
> **Tags:** #DNS #DDNS #Networking

# Domain Setup

This guide covers how to point your custom domain subdomains to your homelab using CNAME records and the MikroTik DDNS service.

## 1. Prerequisites
- A domain registered with Namecheap.
- MikroTik DDNS enabled (refer to `Mikrotik/setup.md`).

## 2. Configuring Namecheap DNS

1. Log in to [Namecheap](https://www.namecheap.com).
2. Navigate to **Domain List** → **Manage** → **Advanced DNS**.
3. For every subdomain you wish to use (e.g., `nextcloud`, `jellyfin`), create a **CNAME Record**:
   - **Type:** `CNAME Record`
   - **Host:** `[SUBDOMAIN]` (e.g., `nextcloud`)
   - **Value:** `[DDNS_NAME].sn.mynetname.net`
   - **TTL:** `Automatic` (or `60 min`)

> [!TIP]
> Using a CNAME record pointing to your MikroTik DDNS URL ensures that your subdomains always resolve to your current public IP address without needing a local update script.

## 3. Local Verification
You can verify the DNS resolution from your local machine:

```bash
# Check if the subdomain resolves to your MikroTik DDNS address
nslookup nextcloud.[DOMAIN]
```

---

# Appendix: Legacy DDNS Method

> [!WARNING]
> This method is legacy and has been replaced by the CNAME method described above. It is kept here for historical reference or for cases where CNAME records cannot be used.

Previously, a custom bash script was used to update A records for subdomains.

### 1. Installation
Install the required libraries:
```bash
sudo apt update 
sudo apt install dnsutils
```

### 2. Configuration
1. Update the custom DDNS updater script (e.g., `update-ddns.sh`) with your subdomain keys.
2. Set the script to run via `crontab`:
```bash
*/10 * * * * /[PATH-TO-SCRIPT]/update-ddns.sh
```

