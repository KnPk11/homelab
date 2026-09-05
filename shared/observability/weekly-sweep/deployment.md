# Weekly 10-minute sweep

Deterministic Sunday timer. **No LLM.** Telegram is fatter than the doorbells and colour-coded:

- 🔴 **RED** — broken control (CrowdSec down, new WAN dstnat, planted file gone). Skip monthly AI until empty.
- 🟠 **AMBER** — maintenance (reboot-required, expected dstnat unpublished). Monthly AI can still run.
- 🟢 **green** — silent.

Host lists live **here**, not in `nodes/*/deployment.md`. Same idea as the [SSH doorbell](../ssh-doorbell/deployment.md). Pointer from [universal node bootstrap](../../docs/universal-node-bootstrap.md) §5.

| Check | Where | What |
| :--- | :--- | :--- |
| Reboot | every Linux sweep host except `syslog` | `/var/run/reboot-required` and `needrestart` kernel stale if installed |
| CrowdSec | `reverse-proxy` | unit active; `mikrotik-bouncer` + `firewall-bouncer` present and not revoked |
| DSTNAT | `ai-tools` via `svc_backup` job key | enabled WAN dstnat matches host-local `/var/lib/weekly-sweep/dstnat.ports`; WG listen-port from `/etc/default/weekly-sweep` |
| Planted files | hosts that have a local expected-path list | `test -e` only. List is mode `600` under `/var/lib/weekly-sweep/` (not in git) |

`syslog` has no planted-file list, so it has no timer.

| Host | Checks |
| :--- | :--- |
| `ai-tools` | dstnat, reboot |
| `proxmox-host` | reboot, planted files |
| `reverse-proxy` | reboot, crowdsec, planted files |
| `docker-services` | reboot, planted files |
| `dns`, `k8s`, `lab-vm`, `nas`, `pbs`, `pulse`, `scratch-pc`, `vpns` | reboot, planted files |

Timers run **on each box**. They do not use God Mode (`ai-key-unlock`). DSTNAT uses `~/.ssh/id_ed25519_mt_backup` like MikroTik capture.

```bash
# from ai-tools, God Mode unlocked (rollout SSH + expected-path copy only)
/opt/dev/homelab_repo/shared/observability/weekly-sweep/rollout.sh
weekly-sweep --dry-run
systemctl start weekly-sweep.service
```

`OnCalendar=Sun 07:00` (local), `Persistent=true`. Telegram env is `/etc/ssh/telegram.env`.

Intended WAN ports live only on **ai-tools**: `/var/lib/weekly-sweep/dstnat.ports`. Git holds `dstnat.ports.example` (80/443 as a format sample). Do not put the real list in the repo. `deploy.sh` will not overwrite an existing host file.

Rollout copies a per-host expected-path list from a map that stays on ai-tools (not in git). Telegram says how many files are missing, not the paths (journal on the host has them).
