# Namecheap Dynamic DNS — Deployment Guide

> [!NOTE]
> **Tags:** #DNS #DDNS #Namecheap #WireGuard #Networking
> **Host:** `ops` (CT 112) | **Interval:** Every 5 minutes

## 1. Overview

This service keeps your primary WAN IP locator record (e.g. `ip.[DOMAIN]`) synchronised with your current residential public IPv4 address using Namecheap's Dynamic DNS API.

WireGuard clients use `ip.[DOMAIN]:51821` as their endpoint. Because this record is updated directly on Namecheap nameservers, it remains 100% independent of MikroTik Cloud (`mynetname.net`) and provides reliable remote access during third-party DDNS outages.

---

## 2. Prerequisites & Secrets

Runtime file: `/srv/namecheap-ddns/ddns.env` (mode `600`). Git holds `ddns.env.example` and the SOPS-encrypted `ddns.env` (Master Admin key fallback). Decrypt from `ai-tools` (`sops-key-unlock`) and copy to `ops`:

```bash
install -d -m 700 /srv/namecheap-ddns
# From ai-tools after unlocking Master key:
sops -d /opt/dev/homelab_repo/nodes/ops/services/namecheap-ddns/ddns.env \
  | ssh ops 'cat > /srv/namecheap-ddns/ddns.env && chmod 600 /srv/namecheap-ddns/ddns.env'
```

---

## 3. Automated Updates (Cron)

The script checks your current public IP via `api.ipify.org` and compares it against public DNS (`1.1.1.1` / `8.8.8.8`). An API update is only dispatched if an actual IP mismatch or resolution failure is detected.

### Schedule

Edit crontab on `ops`:

```bash
crontab -e
```

Add the job (running every 5 minutes):

```cron
*/5 * * * * /opt/homelab-repo/nodes/ops/services/namecheap-ddns/update-namecheap-ddns.sh >> /var/log/namecheap-ddns.log 2>&1
```

---

## 4. Files

| File | Purpose |
|------|---------|
| `nodes/ops/services/namecheap-ddns/update-namecheap-ddns.sh` | Update script — queries IP and updates Namecheap |
| `nodes/ops/services/namecheap-ddns/ddns.env.example` | Template for required credentials |
| `nodes/ops/services/namecheap-ddns/ddns.env` | SOPS-encrypted credentials (Master Admin key) |
| `/srv/namecheap-ddns/ddns.env` | Decrypted runtime secrets (`600`) |
