# Lychee Gallery Setup

> [!NOTE]
> #Lychee #Gallery #Photos #Docker

## 1. Description

**Lychee** is a modern, high-performance photo management system backed by SQLite and FrankenPHP. It provides dynamic album organisation, public/unlisted link sharing, responsive square mosaic layouts, and server-side directory synchronization over existing NAS photo collections via read-only symlinks.


## 2. Configuration

1. Deploy the stack using Portainer or Docker Compose.
2. Add a subdomain and create a Caddy reverse-proxy entry.


## 3. Account & Credential Management

To update the admin user credentials via CLI:

```bash
docker exec lychee php artisan lychee:update_user [USERNAME] [PASSWORD]
```


## 4. Directory Import (CLI Synchronization)

To import photos directly from the read-only NAS mount into Lychee without duplicating files:

```bash
docker exec lychee php artisan lychee:sync /space-photos/ --owner_id=1 --import_via_symlink=1 --dry_run=0
```
> [!TIP]
> When an album has nested sub-directories (e.g. `space-photos/subdirectory`), parent unlisted links require public read access enabled on child albums.


## 5. Custom CSS Styling

Custom styling rules (such as compact banner heights) are maintained in `/srv/lychee/config/user.css`:

```css
/* Compact hero header banner height (~90px height) */
.h-1\/2-screen {
    height: 12.5vh !important;
}
header.header, .header-container {
    max-height: 12.5vh !important;
    min-height: 90px !important;
}
```
