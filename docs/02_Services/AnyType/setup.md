# AnyType

> [!NOTE]
> **Tags:** #anytype #productivity #sync #docker_repository

## 1. Installation

> [!NOTE]
> **Reference**: [As seen here](https://youtu.be/D8ZntmTs1Vs?si=kJRGAM0_MzkqOTrO)

Clone the repository:

```bash
cd /data/repositories
git clone https://github.com/anyproto/any-sync-dockercompose.git
cd any-sync-dockercompose
```

Set the environmental variable overrides in `.env.override`:

```bash
# External domain
EXTERNAL_LISTEN_HOSTS=example.com

# Storage limits: 10 GB
ANY_SYNC_FILENODE_DEFAULT_LIMIT=10737418240

# Storage location
STORAGE_DIR=/mnt/pool/Apps/AnyType
```

Set the correct permissions for external storage:

```bash
sudo chown -R 1000:1000 /mnt/pool/Apps/AnyType
sudo chmod -R 755 /mnt/pool/Apps/AnyType
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

After the first run, import `/data/repositories/any-sync-dockercompose/etc/client.yml` into Anytype apps (in AnyType client select `Self-hosted`).

If you need to make any changes stop the docker containers and run this to rebuild next time:

```bash
sudo rm -rf ./etc/any-sync-filenode
```

## 2. Updating

```bash
cd /data/repositories/any-sync-dockercompose
```

Stop & update:

```bash
make stop
make update
```

## 3. Troubleshooting

### Sync Issues

Make sure the router firewall is not blocking return traffic from the homelab subnet, and AdGuard's static `/etc/hosts` entry is routing `example.com` to the reverse proxy container instead of the AnyType server. Fixed by adding firewall exceptions for AnyType (`[ANYTYPE-IP]`) and AdGuard DNS (`[ADGUARD-IP]`), removing the DNS override on AdGuard, and relying on MikroTik's hairpin NAT to route traffic by port: `443` → Caddy, `1001-1006` → AnyType, `media ports` → MediaMTX.
