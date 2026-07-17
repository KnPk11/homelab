# AnyType

> [!NOTE]
> **Tags:** #anytype #productivity #sync #docker_repository

Host: **homelab-95** (`[ANYTYPE-IP]`). Upstream stack is cloned under `/srv/anytype-sync-logic`; persistent data under `/srv/anytype`.

Node-specific notes (hardening override, secrets paths):  
`nodes/homelab-95/services/anytype/README.md`

## 1. Installation

> [!NOTE]
> **Reference**: [As seen here](https://youtu.be/D8ZntmTs1Vs?si=kJRGAM0_MzkqOTrO)  
> Upstream: [anyproto/any-sync-dockercompose](https://github.com/anyproto/any-sync-dockercompose)

Clone the repository:

```bash
cd /srv
git clone https://github.com/anyproto/any-sync-dockercompose.git anytype-sync-logic
cd anytype-sync-logic
```

### Configure `.env` (not `.env.override`)

Current upstream expects a single **`.env`** file (copy from the example, then edit).  
`make start` fails if `.env` is missing. A separate `.env.override` is **not** loaded by production start/init (older guides and some test scripts still mention it — ignore for runtime).

```bash
cp .env.example .env
```

Edit at least:

```bash
# Hostnames/IPs clients should dial (space-separated). Advertised into client.yml —
# not bind addresses. For DSTNAT + LAN, domain + host LAN IP is typical:
EXTERNAL_LISTEN_HOSTS="example.com [ANYTYPE-IP]"

# Storage limit (bytes). Example: 2 GiB
ANY_SYNC_FILENODE_DEFAULT_LIMIT=2147483648

# Persistent data (app disk on this host)
STORAGE_DIR=/srv/anytype
```

Other useful defaults already in `.env.example`:

- **Mongo / Redis / metrics** published to **`127.0.0.1` only** — leave that.
- Client-facing any-sync ports **1001–1006 TCP** and **1011–1016 UDP** stay on all interfaces so LAN / hairpin / DSTNAT work.

Create storage and permissions:

```bash
mkdir -p /srv/anytype
sudo chown -R 1000:1000 /srv/anytype
sudo chmod -R 755 /srv/anytype
```

### Hardening override (recommended)

Homelab overlay: `nodes/homelab-95/services/anytype/docker-compose.override.yml`  
(no-new-privileges, selective `cap_drop`, log rotation, resource limits). It does **not** change client port publishes.

On the AnyType host, place it next to upstream compose (copy if this repo is not mounted on the node):

```bash
# From a machine that has the GitOps repo (e.g. ai-tools):
scp .../nodes/homelab-95/services/anytype/docker-compose.override.yml \
    root@[ANYTYPE-IP]:/srv/anytype-sync-logic/docker-compose.override.yml

cd /srv/anytype-sync-logic
docker compose config >/dev/null   # merge sanity-check
```

Details: `nodes/homelab-95/services/anytype/README.md`.

### Start

```bash
cd /srv/anytype-sync-logic
make start
```

After first start, network identity is stored under:

- `/srv/anytype/docker-generateconfig/` (`.networkId`, accounts, keys)
- `/srv/anytype-sync-logic/etc/` (including **`client.yml`** for apps)

Import **`/srv/anytype-sync-logic/etc/client.yml`** into Anytype (Self-hosted → upload → **Save** → create/login).

### Port forwarding (MikroTik DSTNAT)

```cfg
TCP: 1001:1006  →  [ANYTYPE-IP]
UDP: 1011:1016  →  [ANYTYPE-IP]
```

### Changing listen hosts or limits later

1. Edit **`.env`**
2. Stop stack: `make stop`
3. Re-run config generation **without** wiping network identity:

   ```bash
   docker compose run --rm --no-deps any-sync-init
   make start
   ```

4. Re-import **`etc/client.yml`** on clients if addresses changed.

Do **not** delete `/srv/anytype/docker-generateconfig/.networkId` (or the whole generateconfig tree) unless you intend a **new** network and new vaults.

If you only need to force filenode config regen in older workflows:

```bash
# rarely needed; prefer full any-sync-init as above
sudo rm -rf ./etc/any-sync-filenode
```

## 2. Updating

> [!IMPORTANT]
> Always **back up the vault** before updating the repository as a good measure.

```bash
cd /srv/anytype-sync-logic
make stop
git pull                    # get new compose/Makefile if needed
# re-apply custom lines in .env if .env.example gained new keys
make update                 # pull images + start  (or: make pull && make start)
```

After compose layout changes, re-check merge and override:

```bash
docker compose config >/dev/null
# refresh docker-compose.override.yml from the GitOps repo if you edited it there
```

For major upgrades, version pins, and env-format changes:

- [any-sync-dockercompose Upgrade Guide](https://github.com/anyproto/any-sync-dockercompose/wiki/Upgrade-Guide)

## 3. Secrets backup

On-demand only: `shared/scripts/scrape_secrets.sh` (see script header). Pulls:

| Path | Why |
|------|-----|
| `/srv/anytype-sync-logic/.env` | Hosts, limits, storage, pins |
| `/srv/anytype/docker-generateconfig/` | Same `networkId` / accounts |
| `/srv/anytype-sync-logic/etc/` | **`client.yml`**, daemon configs, MinIO creds |

Treat `client.yml` as **confidential** (join config for your network), not as sensitive as a recovery phrase.

## 4. DNS & Reachability (WAN / LAN / VPN)

`EXTERNAL_LISTEN_HOSTS` should list what **clients dial**. With one hostname shared by Caddy and AnyType:

- **Caddy (TCP 80, 443):** `[CADDY-IP]`
- **AnyType (TCP 1001–1006, UDP 1011–1016):** `[ANYTYPE-IP]`

Use **port-based DSTNAT** on the router (`dst-address-type=local`), not a DNS rewrite of the domain to Caddy alone.

### Firewall Requirements

1. **DSTNAT**: Caddy ports → `[CADDY-IP]`; AnyType ports → `[ANYTYPE-IP]`.

### Quick Verification

```bash
# Verify VPN DNS (should return router gateway)
dig +short [DOMAIN] @[WG-GW-IP]          # Expect: [ROUTER-IP]

# Verify LAN DNS (should return public IP)
dig +short [DOMAIN] @[ADGUARD-IP]        # Expect: [PUBLIC-IP]
```

### Security notes (short)

- Vault/object data is E2E encrypted; **open sync ports are still an attack surface** (join fabric, DoS, bugs).
- Upstream already localhost-binds mongo, redis, metrics, node APIs.
- Apply the **compose override** for container hardening; it is complementary to network controls.
- CrowdSec on this host does **not** parse any-sync specifically; shared LAPI bans from HTTP/SSH still help at the edge.
