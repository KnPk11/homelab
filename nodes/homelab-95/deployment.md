# Deployment Strategy for homelab-95

## General model

1. **GitOps clone** (`/opt/homelab-repo`) holds tracked compose files, templates, and deploy scripts only. It is disposable (`auto_pull` may hard-reset it).
2. **Runtime secrets** live under **`/srv/<service>/`** as **real files** only (no secret content and no reverse-symlinks back into the clone).
3. **Host scripts** (e.g. UFW) live under **`/opt/scripts/...`** with their own env files.
4. **Compose `${VAR}` interpolation** (domains etc.): set those in Portainer stack env, or keep a host-local `.env` **only under `/srv/<service>/`** if you run compose with that project directory — not inside the GitOps tree.

After a nuke-and-pave: restore `/srv` (and `/opt/scripts`) from the secrets vault, re-run deploy scripts, update Portainer stacks. A bare `git pull` is not enough.

### Secret naming conventions

| Kind | Pattern | Examples |
| :--- | :--- | :--- |
| Compose project env (domains, multi-key config) | **`/srv/<service>/.env`** | grafana, n8n, vaultwarden, webdav, nextcloud, airflow, … |
| Prefixed multi-key env (deploy scripts, not Compose auto-load) | **`/srv/<service>/<service>.env`** | `dashy/dashy.env`, `dozzle/dozzle.env` |
| Single password / token / key file | **`/srv/<service>/<name>.secret`** | `*_password.secret`, `*_token.secret`, raw tokens |
| App-specific password files | keep upstream name when required | `glances.pwd` |

Docker Compose only auto-loads a file named **`.env`** for `${VAR}` interpolation in compose files — do not rename those to `service.env` unless you also change how Portainer supplies env.

### Layout examples

```text
/srv/grafana/.env                         # GRAFANA_DOMAIN=...
/srv/grafana/grafana_password.secret      # raw password
/srv/n8n/.env
/srv/n8n/n8n_password.secret
/srv/filebrowser-quantum/filebrowser_password.secret
/srv/dashy/dashy.env                      # used by deploy_app.sh → config.yml
/srv/dbt/.env                             # used by deploy_app.sh → profiles.yml
/srv/dbt/.secrets/postgres_password.secret
/srv/dbt/.secrets/gcp-creds.json
/opt/scripts/Security/ufw.env
```

### First-time / restore checklist

1. Pull GitOps repo to `/opt/homelab-repo`.
2. Restore secret files under `/srv/<service>/` from the vault (or recreate from `*.example` files in the repo).
3. Run service deploy scripts where needed (Dashy, PrivateBin, MediaMTX, DBT, Nextcloud, …).
4. Deploy or update Portainer stacks from the compose files in the repo (paths already default to `/srv/...`).

## UFW firewall

See [scripts/deployment.md](scripts/deployment.md) — env under `/opt/scripts/Security/ufw.env`.

## DBT service

1. Place secrets on the host:
   ```bash
   sudo mkdir -p /srv/dbt/.secrets
   sudo cp nodes/homelab-95/services/dbt/.env.example /srv/dbt/.env   # from the clone; edit
   # postgres_password.secret and gcp-creds.json under /srv/dbt/.secrets/
   ```
2. Render profiles:
   ```bash
   sudo /opt/homelab-repo/nodes/homelab-95/services/dbt/deploy_app.sh
   ```
3. Deploy the stack in Portainer using the compose file in the repo.

## Other services with deploy scripts

| Service | Deploy script | Secret location |
| :--- | :--- | :--- |
| Dashy | `services/dashy/deploy_app.sh` | `/srv/dashy/dashy.env` |
| PrivateBin | `services/privatebin/deploy.sh` | `/srv/privatebin/.env` |
| MediaMTX | `services/mediamtx/deploy_app.sh` | `/srv/mediamtx/.env` |
| Nextcloud | `services/nextcloud/deploy.sh` | `/srv/nextcloud/` |
