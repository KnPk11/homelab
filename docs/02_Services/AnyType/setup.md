# AnyType

> [!NOTE]
> **Tags:** #anytype #productivity #sync #docker_repository

## 1. Installation

> [!NOTE]
> **Reference**: [As seen here](https://youtu.be/D8ZntmTs1Vs?si=kJRGAM0_MzkqOTrO)

Clone the repository:

```bash
cd /srv
git clone https://github.com/anyproto/any-sync-dockercompose.git anytype-sync-logic
cd anytype-sync-logic
```

Set the environmental variable overrides in `.env.override`:

```bash
# External domain
EXTERNAL_LISTEN_HOSTS=example.com

# Storage limits: 10 GB
ANY_SYNC_FILENODE_DEFAULT_LIMIT=10737418240

# Storage location
STORAGE_DIR=/srv/anytype
```

Set the correct permissions for external storage:

```bash
sudo chown -R 1000:1000 /srv/anytype
sudo chmod -R 755 /srv/anytype
```

Start the service:

```bash
make start
```

Set port forwarding ranges:

```cfg
TCP: 1001:1006
UDP: 1011:1016
```

After the first run, import `/srv/anytype-sync-logic/etc/client.yml` into Anytype apps (in AnyType client select `Self-hosted`).

If you need to make any changes stop the docker containers and run this to rebuild next time:

```bash
sudo rm -rf ./etc/any-sync-filenode
```

## 2. Updating

```bash
cd /srv/anytype-sync-logic
```

Stop & update:

```bash
make stop
make update
```

## 3. DNS & Reachability (WAN / LAN / VPN)

`EXTERNAL_LISTEN_HOSTS` uses a **single hostname** (`[DOMAIN]`) for multiple backends:
- **Caddy (TCP 80, 443):** `[CADDY-IP]`
- **AnyType (TCP 1001–1006, UDP 1011–1016):** `[ANYTYPE-IP]`

Because one domain resolves to multiple servers, **port-based DSTNAT on the router** (`dst-address-type=local`) is required instead of local DNS rewrites.

### DNS Resolution Behavior

| Client/Resolver | `[DOMAIN]` Resolves To | Routing Path |
|-----------------|------------------------|--------------|
| **WAN / Public DNS** | `[PUBLIC-IP]` / DDNS | WAN → MikroTik DSTNAT by port |
| **LAN / AdGuard (`[ADGUARD-IP]`)** | `[PUBLIC-IP]` (No rewrite) | Hairpin NAT → MikroTik DSTNAT by port |
| **VPN / MikroTik DNS (`[WG-GW-IP]`)** | `[ROUTER-IP]` | Hits local address → MikroTik DSTNAT by port |

> [!WARNING]
> **Do not rewrite `[DOMAIN]` directly to `[CADDY-IP]`.** 
> Doing so bypasses the router's DSTNAT, routing AnyType sync traffic (ports 1001+) directly to Caddy, causing connection timeouts (especially for VPN clients).

### Firewall Requirements

1. **DSTNAT**: Caddy ports → `[CADDY-IP]`; AnyType ports → `[ANYTYPE-IP]`.
2. **Hairpin NAT**: Required for Homelab loopback and VPN masquerading.
3. **Pinhole Rules**: Allow DSTNAT traffic and restrict AnyType outbound strictly to VPN clients (`[ANYTYPE-IP]` → `[VPN-SUBNET]`).
4. **Avoid Anti-patterns**: Do not use broad "allow all" filters or stack competing DNS rewrites on both AdGuard and MikroTik.

### Quick Verification

```bash
# Verify VPN DNS (should return router gateway)
dig +short [DOMAIN] @[WG-GW-IP]          # Expect: [ROUTER-IP]

# Verify LAN DNS (should return public IP)
dig +short [DOMAIN] @[ADGUARD-IP]        # Expect: [PUBLIC-IP]
```
