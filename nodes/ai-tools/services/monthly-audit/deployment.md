# Monthly / occasional audit (ai-tools)

Manual audit job with a **reminder** (that does not need unlocking SSH keys). Homelab Watch only (not tied to Hermes / OpenClaw). Digest shape is the four buckets in the playbook (FIX NOW / TRACK / NEEDS BASELINE UPDATE / ACCEPTED).

## Reminder

Timer is **every Sunday 09:00**. The script skips only if it already sent within 6 days (anti-double-fire), so you get a Homelab Watch nudge **weekly**. No keys. Preview: `monthly-audit-reminder --dry-run`. Force: `monthly-audit-reminder --force`.

## Job

You unlock, then pick depth (flag or prompt):

| Flag | Snapshot |
| :--- | :--- |
| `--light` | CrowdSec/Caddy skim, MikroTik DSTNAT + control plane, key status, reboot flags, apt simulation, docker image names, secret **modes** only |
| `--deep` | light + Lynis `--quick` on guests + Docker Bench WARN/FAIL on `docker-services` |

Then LLM → Homelab Watch. God Mode stays loaded for your usual TTL; pass `--lock` if you want it unloaded before the model runs. Empty buckets stay in the message.

`--llm agy` or `--llm grok` is **required** (no default). Antigravity runs `agy --print --mode plan --sandbox --json-schema`. Optional `AUDIT_MODEL` in `/etc/default/monthly-audit`. Do not use `agy --dangerously-skip-permissions`.

```bash
ai-key-unlock && source ~/.ssh/ai-key-agent.sh
monthly-audit --light --llm agy
monthly-audit --light --llm grok
monthly-audit --deep --llm agy
monthly-audit --deep --llm grok
```

Debug: `--no-llm` writes `/var/lib/monthly-audit/latest` and stops before the model. Retry the model on an existing snapshot (no God Mode): `monthly-audit --from-snap --llm grok`.

Grok is `grok --prompt-file` with inline `--json-schema`, `--max-turns 8`, `--verbatim`, and tools denied so it cannot spend the turn on `read_file`.

Playbook: [security-audit-playbook.md](../../../../docs/03_Maintenance/security-audit-playbook.md). Pointer: [universal node bootstrap](../../../../shared/docs/universal-node-bootstrap.md) §5.
