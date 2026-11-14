# VS Code Server prune (disk cleanup)

> [!NOTE]
> #Maintenance #VSCode #Disk

Remote-SSH leaves old `~/.vscode-server` builds (~600–700 MB each). Small disks (LXCs, scratch-pc) fill up over a few client updates.

## Script

**Source (repo):** `shared/scripts/prune-vscode-server.sh`  
**On nodes (until GitOps deploys it):** `/usr/local/sbin/prune-vscode-server.sh`

Universal **on-host** cleaner (run on the machine itself — not multi-SSH).

| Behaviour | Detail |
|---|---|
| Keeps | Running session commit(s) + newest `lru.json` entry + optional extras |
| Does **not** | `pkill` sessions, wipe `~/.cache` |
| Default | Dry-run; pass `--apply` to delete |

```bash
# dry-run
sudo /usr/local/sbin/prune-vscode-server.sh --keep-extra 1

# apply (typical weekly)
sudo /usr/local/sbin/prune-vscode-server.sh --apply --keep-extra 1 --all
```

`--all` also dedupes extensions, prunes old logs/history, and clears VSIX cache.

## Cron Setup

Scheduled as **root** every **3 days at 03:00** (before the PBS guest backup window) on **`scratch-pc`**, **`ai-tools`**, and **`ops`**:

- **`scratch-pc`** (crontab) and **`ai-tools`** (`/etc/cron.d/prune-vscode-server` via [`nodes/ai-tools/scripts/deploy-hygiene.sh`](../../nodes/ai-tools/scripts/deploy-hygiene.sh)):

```cron
0 3 */3 * * root /usr/local/sbin/prune-vscode-server.sh --apply --keep-extra 1 --all >> /var/log/prune-vscode-server.log 2>&1
```

- **`ops`** (`/etc/cron.d/prune-vscode-server` via [`nodes/ops/scripts/deploy-hygiene.sh`](../../nodes/ops/scripts/deploy-hygiene.sh) — uses `--keep-extra 0` for the 3.9 GB root disk):

```cron
0 3 */3 * * root /usr/local/sbin/prune-vscode-server.sh --apply --keep-extra 0 --all >> /var/log/prune-vscode-server.log 2>&1
```

Log: `/var/log/prune-vscode-server.log` (rotated on `ai-tools` and `ops` via `/etc/logrotate.d/`).

Manual one-offs on other hosts are fine; keep automated schedules limited to hosts with recurring VS Code Remote-SSH churn.

## Notes

- After a VS Code client update, one reconnect may re-download a missing build — expected.
- Until the script is committed and auto-pulled, updating the on-node copy means re-copying to `/usr/local/sbin/`.
