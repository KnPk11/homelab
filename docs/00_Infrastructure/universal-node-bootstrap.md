# Universal Node Bootstrap Guide

This guide outlines the standard boilerplate procedure required to bring any new or rebuilt node into the GitOps automation fold. This must be the very first step performed on a node before deploying any of its specific services.

## 1. Install Prerequisites

Ensure the machine has `git` installed:

```bash
# Debian/Ubuntu / Proxmox LXC
apt-get update && apt-get install -y git rsync

# Alpine
apk add git rsync
```

## 2. Clone the Repository

Clone the public homelab repository into the standardised `/opt/homelab-repo` directory:

```bash
git clone https://github.com/KnPk11/homelab.git /opt/homelab-repo
```

## 3. Enable GitOps Automation (Cron & On-Demand)

We use a shared script (`auto_pull_repo.sh`) to ensure target nodes track `origin/main` safely.

> [!IMPORTANT]
> **Authoring Node Exclusion (`ai-tools`)**:
> Never schedule `auto_pull_repo.sh` on **`ai-tools`**. As the central development and authoring workstation (`/opt/dev/homelab_repo`), `ai-tools` is guarded automatically by the script to prevent overwriting active development branches or uncommitted work.

### Safe Auto-Pull Behaviour (`auto_pull_repo.sh` v2.0)
- **Non-Destructive Fast-Forward**: Performs a clean `git merge --ff-only` rather than an arbitrary hard reset.
- **Dirty Tree Protection**: Checks `git status --porcelain`. If uncommitted changes exist (e.g. during live debugging), it logs a warning and skips the pull, preserving your work.
- **Change Detection**: Compares `HEAD` against `origin/main` and only touches the filesystem if remote commits exist.
- **Force Mode (`--force`)**: If you explicitly need to discard local changes and snap strictly to remote, pass `--force`.

### Setting Up the Scheduled Cronjob (Target Nodes Only)
To prevent all nodes from hitting GitHub at the exact same second, **stagger execution minutes**. Check the node's specific `deployment.md` playbook for its assigned minute offset:

1. Open the crontab editor:
   ```bash
   crontab -e
   ```
2. Add the following entry (replacing `XX` with the node's assigned minute):
   ```bash
   XX * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1
   ```

### On-Demand Fleet Synchronisation (`sync-nodes`)
Rather than waiting up to an hour for background cron ticks, you can dispatch immediate synchronisation directly from **`ai-tools`** over SSH using the `sync-nodes` utility (symlinked from `shared/scripts/sync_nodes.sh`):

```bash
# Check current git commit status across nodes without pulling:
sync-nodes --status all
sync-nodes --status ops docker-services

# Immediately pull updates to specific nodes:
sync-nodes ops
sync-nodes docker-services k8s lab-vm

# Immediately pull updates across all online fleet nodes:
sync-nodes all

# Force reset nodes with dirty trees (if required):
sync-nodes --force ops
```

### Repository Scope & Deployment Rationale

`auto_pull_repo.sh` manages specific repositories based on their execution model:

| Repository | Auto-Pull Enabled? | Rationale |
| :--- | :--- | :--- |
| **`/opt/homelab-repo`** | **Yes** (All nodes) | Fleet-wide infrastructure configs, maintenance playbooks, and shared system utilities across all 13 Linux nodes. Updates take effect on subsequent script executions without requiring process restarts. |
| **`/opt/de-portfolio`** | **Yes** (`docker-services` & `k8s`) | Apache Airflow DAGs (`/srv/airflow/dags -> /opt/de-portfolio/airflow`) on `docker-services`; Apache Spark data processing pipelines (`/opt/de-portfolio/spark`) on `k8s`. Automatically synchronised for dynamic job execution. |
| **`/opt/web-apps`** | **No** (Deliberately excluded) | Web applications (`story-cards`, `homelab-dashboard`) run persistent in-memory processes (Python, Node). Background Git pulls do not restart running daemons and risk desynchronising dependencies (`venv`, `npm`) or database schemas. Web applications are updated via deliberate push/SSH deployments (`git pull` followed by process restart and verification). |
| **`/opt/web-apps-private`** | **No** (Ad-hoc / Private) | Ad-hoc, experimental, or untracked private applications and background monitors on `scratch-pc` or `lab-vm` (e.g. `rtx-5090-scan-monitor`). Managed locally or synced from `ai-tools:/opt/dev/projects_private/`. Decoupled completely from public GitOps automation. |

> [!NOTE]
> **Application Directory Conventions**:
> - **`/opt/web-apps`**: Public web applications repository (`github.com/KnPk11/web-apps`). Deployed explicitly.
> - **`/opt/web-apps-private`**: Private, experimental, or host-specific applications and ad-hoc scripts. Authored under `ai-tools:/opt/dev/projects_private/` or maintained host-locally, kept completely outside public GitOps pipelines.

## 4. Proceed to Node-Specific Playbook

Once the node is bootstrapped and pulling changes autonomously, return to the node's specific `deployment.md` file to deploy its services.

## 5. Fleet-wide Homelab Watch

Rolled out from **`ai-tools`**. Do **not** copy these into each `nodes/*/deployment.md` — the host lists live with the scripts.

*   [SSH doorbell](../../shared/observability/ssh-doorbell/deployment.md) — PAM successful SSH on every Linux SSH host.
*   [Weekly sweep](../../shared/observability/weekly-sweep/deployment.md) — Sunday timer. Reboot flags on the Linux sweep hosts, CrowdSec on reverse-proxy, DSTNAT from ai-tools, planted-file presence where a local list exists.
*   [Monthly audit](../../nodes/ai-tools/services/monthly-audit/deployment.md) — reminder timer on **ops** (CT 112). You unlock God Mode on **ai-tools** and run `--light` or `--deep`; Antigravity (`agy`) or Grok tags the snapshot; digest to Homelab Watch.
*   [WAN saturation](../../nodes/ops/services/wan-saturation/deployment.md) — **ops** only. Minute poll of `pppoe-out1` via `mikrotik-backup`; Homelab Watch if RX/TX stay near the ISP circuit.

```bash
# on ai-tools, God Mode unlocked
/opt/dev/homelab_repo/shared/observability/ssh-doorbell/rollout.sh
/opt/dev/homelab_repo/shared/observability/weekly-sweep/rollout.sh

# on ops (CT 112)
/opt/homelab-repo/nodes/ops/services/monthly-audit-reminder/deploy.sh
/opt/homelab-repo/nodes/ops/services/wan-saturation/deploy.sh
```
