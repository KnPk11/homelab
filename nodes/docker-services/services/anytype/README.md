# AnyType Service (Self-Hosted)

Upstream **any-sync-dockercompose** runs from a git clone on the host so `docker-compose.yml` stays mergeable with upstream. This GitOps path only holds the **hardening override** and operational notes.

## Architecture

| Role | Path |
|------|------|
| Code / compose | `/srv/anytype-sync-logic` ([anyproto/any-sync-dockercompose](https://github.com/anyproto/any-sync-dockercompose.git)) |
| State / storage | `/srv/anytype` (`STORAGE_DIR` in `.env`) |
| Generated network + `client.yml` | `/srv/anytype-sync-logic/etc/` |
| Network identity (persistent) | `/srv/anytype/docker-generateconfig/` |
| Runtime config | `/srv/anytype-sync-logic/.env` only |
| Hardening override (this repo) | `docker-compose.override.yml` |

## Environment (`.env`)

Upstream no longer uses a separate **`.env.override`** for production. Workflow:

```bash
cd /srv/anytype-sync-logic
cp -n .env.example .env   # first install only
# edit .env — EXTERNAL_LISTEN_HOSTS, STORAGE_DIR, ANY_SYNC_FILENODE_DEFAULT_LIMIT, …
make start
```

Current production-style values (example):

```bash
EXTERNAL_LISTEN_HOSTS="example.com [ANYTYPE-IP]"   # domain + LAN; space-separated
ANY_SYNC_FILENODE_DEFAULT_LIMIT=2147483648            # 2 GiB
STORAGE_DIR=/srv/anytype
```

`EXTERNAL_LISTEN_HOSTS` is **advertised into `client.yml`**, not a bind list. Port publishes for clients remain host-wide (0.0.0.0) so DSTNAT/LAN work. Mongo/redis/metrics stay on `127.0.0.1` via `.env` defaults.

After changing listen hosts: edit `.env` → `make stop` → `docker compose run --rm --no-deps any-sync-init` → `make start` → re-import `etc/client.yml`. Identity is kept if `docker-generateconfig/.networkId` is left intact.

## Hardening override

File in this directory: `docker-compose.override.yml`.

Compose merges any `docker-compose.override.yml` beside upstream `docker-compose.yml`.

**Install on docker-services** (repo is often only on ai-tools — use **copy**, not symlink, unless the repo is mounted on the node):

```bash
scp /opt/dev/homelab_repo/nodes/docker-services/services/anytype/docker-compose.override.yml \
    root@[ANYTYPE-IP]:/srv/anytype-sync-logic/docker-compose.override.yml

ssh root@[ANYTYPE-IP] 'cd /srv/anytype-sync-logic && docker compose config >/dev/null && docker compose up -d'
```

**What it applies:**

| Control | Targets |
|---------|---------|
| `security_opt: no-new-privileges` | Long-running + one-shot services |
| Selective `cap_drop` (high-risk caps) | mongo, redis, minio, any-sync daemons, netcheck |
| Log rotation (`json-file` max 10m × 3) | Same |
| CPU/memory `deploy.resources.limits` | Data plane + daemons |

**Intentionally not applied** (breaks any-sync or client access):

- `read_only: true` on daemons  
- `cap_drop: ALL` without careful `cap_add`  
- Binding client ports **1001–1006 / 1011–1016** to localhost only  

Verify live:

```bash
docker inspect anytype-sync-logic-any-sync-coordinator-1 \
  --format 'SecurityOpt={{json .HostConfig.SecurityOpt}} CapDrop={{len .HostConfig.CapDrop}} Memory={{.HostConfig.Memory}}'
# Expect: no-new-privileges:true, CapDrop>0, Memory set (e.g. 524288000)
```

After major upstream `git pull` / compose renames: `docker compose config` and re-copy the override if needed.

## Secrets management

`shared/scripts/scrape_secrets.sh` backs up:

| Path | Why |
|------|-----|
| `/srv/anytype-sync-logic/.env` | Hosts, limits, storage, pins |
| `/srv/anytype/docker-generateconfig/` | `networkId`, signing key, node accounts |
| `/srv/anytype-sync-logic/etc/` | **`client.yml`**, daemon configs, MinIO creds |

`client.yml` is confidential (network join file), not equivalent to a vault recovery phrase. Do **not** commit real `.env` or `etc/` to public Git. Scrape on demand only; vault offline after.

## Install / update docs

- `docs/02_Services/AnyType/setup.md`
- `docs/02_Services/AnyType/storage-split.md`
- Upstream: [Upgrade Guide](https://github.com/anyproto/any-sync-dockercompose/wiki/Upgrade-Guide)
