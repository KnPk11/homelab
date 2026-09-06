# Monthly / occasional audit (ai-tools)

Manual audit job with a **reminder** (that does not need unlocking SSH keys). Homelab Watch only (not tied to Hermes / OpenClaw). Digest shape is the four buckets in the playbook (FIX NOW / TRACK / NEEDS BASELINE UPDATE / ACCEPTED).

## Reminder

Timer is **every Sunday 09:00**; the script skips if it already sent within 13 days, so you get a fat Homelab Watch nudge **every other Sunday**. No keys. Preview: `monthly-audit-reminder --dry-run`. Force: `monthly-audit-reminder --force`.

## Job

You unlock, then pick depth (flag or prompt):

| Flag | Snapshot |
| :--- | :--- |
| `--light` | CrowdSec/Caddy skim, MikroTik DSTNAT + control plane, key status, reboot flags, apt simulation, docker image names, secret **modes** only |
| `--deep` | light + Lynis `--quick` on guests + Docker Bench WARN/FAIL on `docker-services` |

Then: **`ai-key-lock`** → Grok CLI (`--prompt-file`, JSON schema, no extra SSH) → Homelab Watch. Empty buckets stay in the message.

```bash
ai-key-unlock && source ~/.ssh/ai-key-agent.sh
monthly-audit --light
# or
monthly-audit --deep
```

Debug: `--no-lock --no-llm` writes `/var/lib/monthly-audit/latest` and leaves keys loaded.

Playbook: [security-audit-playbook.md](../../../../docs/03_Maintenance/security-audit-playbook.md). Pointer: [universal node bootstrap](../../../../shared/docs/universal-node-bootstrap.md) §5.
