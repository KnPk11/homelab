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

## 3. GitOps Synchronisation Model (On-Demand Dispatch)

The homelab operates on a **deliberate, on-demand GitOps model** rather than background cron polling. Updates are authored and pushed to GitHub from **`ai-tools`**, then fanned out across the fleet on-demand via the `sync-nodes` utility.

### Fleet Dispatcher (`sync-nodes`)
From **`ai-tools`**, dispatch immediate repository pulls across target nodes over SSH:

```bash
# Check current git commit status across all nodes without pulling:
sync-nodes --status all

# Pull updates to specific nodes:
sync-nodes ops
sync-nodes docker-services k8s lab-vm

# Synchronise all online fleet nodes at once:
sync-nodes all

# Force reset nodes with dirty trees (if required):
sync-nodes --force ops
```

### Node Pull Script (`auto_pull_repo.sh` v2.0)
When executed (either via `sync-nodes` over SSH or manually on the host), `/opt/homelab-repo/shared/scripts/auto_pull_repo.sh` enforces safety checks:
- **Non-Destructive Fast-Forward**: Performs a clean `git merge --ff-only` rather than an arbitrary hard reset.
- **Dirty Tree Protection**: Checks `git status --porcelain`. If uncommitted changes exist (e.g. during live debugging), it logs a warning and skips the pull to prevent data loss.
- **Change Detection**: Compares `HEAD` against `origin/main` and only touches files if remote commits exist.
- **Authoring Guard**: Hard-refuses to run on `ai-tools` to protect active development checkouts.

> [!NOTE]
> **No Crontab Entry Required**:
> Background cron jobs for `auto_pull_repo.sh` are decommissioned across all nodes. This prevents silent divergence, eliminates background API polling churn, and ensures code is only updated on appliances when deliberately deployed.

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
