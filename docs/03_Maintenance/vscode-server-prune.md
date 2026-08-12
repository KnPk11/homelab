# VS Code Server prune (disk cleanup)

> [!NOTE]
> #Maintenance #VSCode #Disk

Remote-SSH leaves old `~/.vscode-server` builds (~600–700 MB each). Small disks (LXCs, scratch-pc) fill up over a few client updates.

## Script

**Source (repo):** `shared/scripts/prune_vscode_server.sh`  
**On nodes (until GitOps deploys it):** `/usr/local/sbin/prune_vscode_server.sh`

Universal **on-host** cleaner (run on the machine itself — not multi-SSH).

| Behaviour | Detail |
|---|---|
| Keeps | Running session commit(s) + newest `lru.json` entry + optional extras |
| Does **not** | `pkill` sessions, wipe `~/.cache` |
| Default | Dry-run; pass `--apply` to delete |

```bash
# dry-run
sudo /usr/local/sbin/prune_vscode_server.sh --keep-extra 1

# apply (typical weekly)
sudo /usr/local/sbin/prune_vscode_server.sh --apply --keep-extra 1 --all
```

`--all` also dedupes extensions, prunes old logs/history, and clears VSIX cache.

## Cron Setup

**Only** installed on **scratch-pc** (throwaway / safe testing box). Do **not** enable this on production LXCs or lab-vm unless intentionally expanded later.

Installed as **root**, every **3 days at 03:00** (before the PBS guest backup window):

```cron
0 3 */3 * * /usr/local/sbin/prune_vscode_server.sh --apply --keep-extra 1 --all >> /var/log/prune-vscode-server.log 2>&1
```

Log: `/var/log/prune-vscode-server.log`

Manual one-offs on other hosts are fine; no fleet-wide cron.

## Notes

- After a VS Code client update, one reconnect may re-download a missing build — expected.
- Until the script is committed and auto-pulled, updating the on-node copy means re-copying to `/usr/local/sbin/`.
