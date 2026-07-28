# Hermes Security

> [!NOTE]
> #Hermes #Security #Firewall #UFW #Proxmox #HomeLab

Multi-layer access control for the Hermes dashboard and API keys. Install and provider setup live in [setup.md](setup.md).

## 1. Description

Hermes is exposed only through trusted paths: no public port-forward for the dashboard, hypervisor and guest firewalls restrict who can reach the VM, Caddy enforces LAN-only HTTPS, and the app itself requires native `scrypt` login.

## 2. Security Layers

### Perimeter (MikroTik)

- No port-forward for the Hermes dashboard port (`9119`).
- Direct internet access to the dashboard is blocked at the edge.

### Hypervisor (Proxmox)

- Guest firewall allows the **Caddy** reverse proxy to the Hermes port on the OpenClaw VM.
- Other internal sources to that port are dropped before the VM.

### Guest firewall (UFW)

- OpenClaw UFW limited to trusted subnets (`[LAN-TRUSTED].0/24`, `[LAN-SERVERS].0/24`).

### Application (Caddy)

- LAN-only access policy; non-local clients get `403`.
- TLS termination on Caddy; Hermes handles application auth.

```caddy
hermes.[DOMAIN] {
    import common-headers
    import common-robots
    import access_policy_lan
    import common-logging-plaintext hermes
    import common-logging hermes

    reverse_proxy [CADDY-IP]:9119 {
        header_up Host [CADDY-IP]:9119
    }
}
```

## 3. Service Binding

> [!IMPORTANT]
> **Safety Justification**
>
> The Hermes dashboard binds to `0.0.0.0` so Caddy can reach it. That is acceptable here only because Proxmox and MikroTik already restrict who can hit the port. If those layers are disabled, re-bind to `127.0.0.1` or allow only the Caddy LXC IP in UFW.

## 4. Native Authentication

Hermes uses native `scrypt` auth (password-manager friendly) for non-loopback binds.

| Setting | Role |
| :--- | :--- |
| Username | Dashboard login user |
| Password hash | `scrypt` (not plaintext) |
| Session secret | 32-byte secret for session signing across restarts |

Configured in `~/.hermes/.env` (not in the main config file):

```bash
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=[USER]
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH=scrypt$16384$8$1$...
HERMES_DASHBOARD_BASIC_AUTH_SECRET=[SECRET]
```

> [!IMPORTANT]
> **Hash generation**
>
> Generate the password hash with Hermes’s helper so the format matches:
> `python -c "from plugins.dashboard_auth.basic import hash_password; print(hash_password('YOUR_PASSWORD'))"`

### Hardening recommendations

- Prefer Caddy + LAN policy over exposing the VM port broadly.
- Rotate dashboard password and session secret periodically.
