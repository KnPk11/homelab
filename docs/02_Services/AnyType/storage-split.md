# AnyType Storage Split

> [!NOTE]
> **Tags:** #anytype #storage #minio #nas

## Objective

Move Minio from local drive to cold storage without breaking the Anytype setup.

## 1. Find the Bloat

```bash
du -h --max-depth=1 /srv/anytype
```

## 2. Choose Your Method

| Method | Pros | Cons |
| :--- | :--- | :--- |
| **Docker Override** | ✅ Clean, survives updates | ❌ Requires YAML |
| **Symlink** | ✅ No YAML needed | ❌ Can be finicky on some configs |

## 3. Execute

### Option A: Docker Override (Recommended)

```bash
# 1. Stop
make stop

# 2. Move data
mv /srv/anytype/minio /mnt/nas/anytype-blobs

# 3. Create override
cat > docker-compose.override.yml << EOF
version: '3.9'
services:
  minio:
    volumes:
      - /mnt/nas/anytype-blobs:/data
EOF

# 4. Restart
make start
```

> [!TIP]
> **Merge Behavior**: Compose merges this with the main stack; keep `STORAGE_DIR=/srv/anytype` in **`.env`**. The volume line below only redirects Minio blobs to the NAS path.

### Option B: Symlink

```bash
# 1. Stop
make stop

# 2. Move data
mv /srv/anytype/minio /mnt/nas/anytype-blobs

# 3. Create link
ln -s /mnt/nas/anytype-blobs /srv/anytype/minio

# 4. Restart
make start
```

> [!NOTE]
> **Compatibility**: Symlinks can be problematic with Windows Docker or Snap installs. Standard Ubuntu/Debian homelabs are fine.

## Result

| Service | Location |
| :--- | :--- |
| Anytype core | `/srv/anytype` |
| Minio blobs | `/mnt/nas/anytype-blobs` |
