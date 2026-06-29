# AnyType Service (Self-Hosted)

Because the AnyType self-hosted setup (any-sync-dockercompose) expects to be run directly from an upstream Git repository clone, its `docker-compose.yml` and configs are **not** tracked in this homelab GitOps repository to prevent merge conflicts with upstream updates.

## Architecture

- **Code/Logic:** `/srv/anytype-sync-logic` (Cloned from `https://github.com/anyproto/any-sync-dockercompose.git`)
- **State/Storage:** `/srv/anytype`
- **Secrets/Configs:** `/srv/anytype/docker-generateconfig`

## Secrets Management

The generated node configurations and `.env.override` are highly sensitive cryptographic keys. They are automatically backed up to the encrypted Secrets Vault via the central `scrape_secrets.sh` cron script.

For installation or storage split instructions, see:
- `docs/02_Services/AnyType/setup.md`
- `docs/02_Services/AnyType/storage-split.md`
