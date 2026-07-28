# WebDAV Security

> [!NOTE]
> #WebDAV #Security #Fail2Ban #Proxy

Recommendations for exposing WebDAV (especially without a VPN). Install and client workarounds live in [setup.md](setup.md).

## 1. Description

WebDAV over the internet is a common brute-force target. Prefer Fail2Ban (or equivalent) on reverse-proxy auth failures, optional geo-blocking, obscure hostnames, and VPN/split-tunnel when possible.

## 2. Brute-force Protection

Ensure brute-force protection is active via Fail2Ban or a Caddy plugin.

```bash
# Example Fail2Ban jail for Caddy WebDAV
[caddy-auth]
enabled = true
port    = http,https
filter  = caddy-auth
logpath = /var/log/caddy/access.log
maxretry = 5
```

Verify unauthorised attempts in the logs:

```bash
tail -f /var/log/caddy/access.log | grep "401"
```

## 3. Geo-blocking

Consider geo-blocking to drop traffic from high-risk regions.

```bash
# In Caddyfile (utilising maxmind-geolocation)
@geoblock {
    not maxmind_geolocation {
        country_code UK EU
    }
}
handle @geoblock {
    abort
}
```

## 4. Additional Tips

- **Obscurity:** Use an obscure subdomain to avoid scanners (e.g. `s7orag3-media.homelab.local` instead of `dav.homelab.local`).
- **Access Control:** Point WebDAV only at specific media directories for broader access; keep sensitive roots on SMB + VPN.
- **VPN Integration:** Split-tunnel so WebDAV stays on VPN without manual toggling.
