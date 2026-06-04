# Caddy Security & Hardening

> [!NOTE]
> **Tags:** #Caddy #Security #Hardening #Proxy

## Overview
Refer to the guide on hardening Caddy at [Hackvisor - Caddy](https://hackviser.com/tactics/hardening/caddy) and use the [Security Headers](https://securityheaders.com/) website to validate the implementation.

---
## SSL & TLS

- **Automatic TLS**: Ensure all Caddy sites have `tls` enabled (automatic with registered domains).
- **Directory Listing**: Disable directory listing unless intentional by removing the `browse` keyword:
```caddyfile
file_server browse  # ← Remove "browse" unless explicitly required
```

- **Permissions**: Caddy runs as `root` by default; it is strongly recommended to run it with a dedicated system user (see `setup.md`) or in an unprivileged container.
- **Bruteforce Detection**: Install **Fail2Ban** or use Caddy logs with a log analyser (like **CrowdSec**) to detect and block malicious attempts.

### Security Headers & protocols
Enable HTTP Strict Transport Security (HSTS) and modern TLS protocols in your Caddyfile:

```caddyfile
header {
  Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
  X-Content-Type-Options "nosniff"
  Referrer-Policy "no-referrer"
}
tls {
  protocols tls1.3
}
```

---
## Authentication & Access Control

### Basic Auth
Utilise **basic auth** or OAuth (e.g., Authelia or an OIDC plugin) for sensitive paths, especially if the backend service:
- Lacks built-in authentication.
- Does not support HTTPS or secure session management.
- Lacks native brute-force protection.

### Rate Limiting
Caddy's `rate_limit` directive can be applied to any path or request using matchers (like `path`, `ip`, or `header`).

```caddyfile
rate_limit {
    distributed
    zone dynamic_zone {
        key {http.request.remote_ip}
        events 1000
        window 30s
    }
}
respond "Rate limited"
```

---
## IP Filtering & Forwarding

### Restricted Access
It is possible to restrict which IPs are allowed to access a particular service. Routing even LAN-only services through Caddy centralises logging and adds a layer of security.

> [!NOTE]
> **Forwarded headers**
> 
> Ensure all backend services (e.g., Nextcloud, Jellyfin) receive the original client IP via `X-Forwarded-For`. This makes the internal security mechanisms of those services more effective.

**Best Practice:** Bind Caddy's internal IP for `X-Forwarded-For` headers instead of a broad range. This prevents an attacker from easily spoofing their IP by pretending to be the reverse proxy.

---
## Privacy (Robots.txt)

To enhance privacy, you can add a global `robots.txt` to discourage crawlers from indexing your services.

**1. Create the file:**
```bash
echo -e "User-agent: *\nDisallow: /" > /srv/robots.txt
```

**2. Add to Caddyfile:**
```caddyfile
handle /robots.txt {
    root * /srv
    file_server
}
```
