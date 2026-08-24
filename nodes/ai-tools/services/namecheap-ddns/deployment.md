# Namecheap Dynamic DNS — Deployment Guide

> [!NOTE]
> **Tags:** #DNS #DDNS #Namecheap #WireGuard #Networking
> **Host:** `ai-tools` | **Interval:** Every 5 minutes

## 1. Overview

This service keeps your primary WAN IP locator record (e.g. `ip.[DOMAIN]`) synchronised with your current residential public IPv4 address using Namecheap's Dynamic DNS API.

WireGuard clients use `ip.[DOMAIN]:51821` as their endpoint. Because this record is updated directly on Namecheap nameservers, it remains 100% independent of MikroTik Cloud (`mynetname.net`) and provides reliable remote access during third-party DDNS outages.

---

## 2. Prerequisites & Secrets

1. Obtain your Dynamic DNS password from [Namecheap](https://ap.www.namecheap.com/):
   * **Domain List** → **Manage** → **Advanced DNS** → **Dynamic DNS** (toggle **ON** and copy the generated password).
2. Ensure the subdomain (e.g. `ip`) is configured under **Advanced DNS** as an **A + Dynamic DNS Record** (pointing to your initial IP or `127.0.0.1`).
3. Store runtime secrets on `ai-tools` under `/srv/namecheap-ddns/ddns.env`:

```bash
mkdir -p /srv/namecheap-ddns
chmod 700 /srv/namecheap-ddns
cat << 'SEC' > /srv/namecheap-ddns/ddns.env
DOMAIN="yourdomain.com"
PASSWORD="your_namecheap_ddns_password"
HOSTS="ip"
LOGFILE="$HOME/namecheap-ddns.log"
SEC
chmod 600 /srv/namecheap-ddns/ddns.env
```

---

## 3. Automated Updates (Cron)

The script checks your current public IP via `api.ipify.org` and compares it against public DNS (`1.1.1.1` / `8.8.8.8`). An API update is only dispatched if an actual IP mismatch or resolution failure is detected.

### Schedule

Edit crontab on `ai-tools`:

```bash
crontab -e
```

Add the job (running every 5 minutes):

```cron
*/5 * * * * /opt/dev/homelab_repo/nodes/ai-tools/services/namecheap-ddns/update-namecheap-ddns.sh >> /var/log/namecheap-ddns.log 2>&1
```

---

## 4. Files

| File | Purpose |
|------|---------|
| `nodes/ai-tools/services/namecheap-ddns/update-namecheap-ddns.sh` | Update script — queries IP and updates Namecheap |
| `nodes/ai-tools/services/namecheap-ddns/ddns.env.example` | Template for required credentials |
| `/srv/namecheap-ddns/ddns.env` | Runtime secrets (**not in Git**) |
