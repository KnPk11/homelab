# AI-Tools-105 Master Bootstrap Guide

This node is the **management / AI tooling** host. It holds the primary working copy of the GitOps repo under `/opt/dev/homelab_repo` (not only `/opt/homelab-repo`), runs central jobs such as secrets scrape and MikroTik config capture, and should stay isolated from general app workloads.

This node follows **Infrastructure as Intent**: prefer tracked scripts and docs in Git; keep real secrets and generated exports out of the remote repository.

**Secrets are not in Git.** Central vault: `/opt/dev/secrets_vault/`. Per-node secrets live on each host under `/srv/…` or `/opt/scripts/…` and are pulled here by `nodes/ai-tools/services/configs-and-secrets-backup/scrape_configs_and_secrets.sh`. After a nuke-and-pave of this host, restore the vault (and any local keys/SSH config) before relying on scrape/cron jobs.

*   **Secrets Vault (`/opt/dev/secrets_vault/`)**:
    *   This directory contains raw runtime secrets (`.env` files, SSH keys, TLS certificates) scraped from nodes.
    *   It is excluded from Git to prevent accidental leaks of production credentials.
    *   *Security Note: Do NOT schedule `scrape_configs_and_secrets.sh` in crontab anymore. Run it purely on-demand so you can immediately move the generated vault offline, minimizing the window that secrets sit on this AI host.*

---

If this machine ever suffers a catastrophic failure, follow the guides below in order.

## 1. System Bootstrap

*   Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** where it applies (this host may already be the Git source of truth rather than a pure pull-only node).
*   Clone or restore **`/opt/dev/homelab_repo`** (and remotes) as your working tree.
*   **Operations Migration:** Unattended operations (DDNS, WAN saturation, MikroTik backups, and Homelab Watch reminders) run on the dedicated **[ops CT 112](../ops/deployment.md)** LXC.

## 2. Services on this node

*   [Configs & secrets scraper](services/configs-and-secrets-backup/scrape_configs_and_secrets.sh) — on-demand scraper sweeping remote `/srv` secrets into central vault.
*   [God Mode + Git SSH key TTL unlock](services/ai-ssh-key/deployment.md) — passphrase-unlock `id_ed25519_ai` (lab) and `id_ed25519` (GitHub; formerly `svc_automation`) into ssh-agent with a **2h TTL** auto-unload watchdog.
*   [SOPS + age (Master vs node keys)](services/sops-key/deployment.md) — Master Admin key in RAM on this host; per-node age keys on appliance boxes. Not the same as God Mode SSH.
*   [Monthly Audit](services/monthly-audit/deployment.md) — interactive snapshot audit run by the AI agent on-demand.
*   [Telegram Terminal](services/telegram-terminal/deployment.md) — Headless mobile terminal wrapper for bash and Antigravity (`agy`) agents via Telegram long-polling.

## 3. Related shared tooling

*   [Secrets scraper](../../shared/scripts/scrape_secrets.sh) — header documents vault layout and `PATH_SWEEPS`.
*   Homelab node secrets model: [docker-services deployment](../docker-services/deployment.md).
