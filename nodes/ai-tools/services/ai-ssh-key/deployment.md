# God Mode + Git SSH Keys — TTL Unlock (ai-tools)

> [!NOTE]
> **Tags:** #SSH #Security #AI #Homelab #GitHub  
> **Host:** ai-tools | **Default TTL:** 2 hours

## 1. Overview

`ai-key-unlock` loads a **bundle** of passphrase-protected keys into one `ssh-agent` for a shared TTL:

| Key | Comment / role |
|-----|----------------|
| `~/.ssh/id_ed25519_ai` | **God Mode** — privileged lab SSH (MikroTik `svc_ai`, LXCs, VMs) |
| `~/.ssh/id_ed25519` | **Git SSH key** (GitHub; comment `git`) — if the file exists |

| Item | Path / value |
|------|----------------|
| Agent env (shared) | `~/.ssh/ai-key-agent.sh` |
| Unlock state | `~/.ssh/ai-key-unlock.state` |

Workflow:

1. **Unlock** when you need lab SSH and/or git (`ai-key-unlock` — passphrase per key).
2. Work (Grok / shell with agent env loaded).
3. **Lock** when done, or let the **2-hour TTL** auto-unload both keys.

Keys stay **separate identities** (do not reuse one private key for lab + GitHub). They only share **agent + TTL UX**.

Automation that must stay passwordless (e.g. MikroTik `svc_backup` capture) uses **other** keys and is unaffected.

## 2. Commands

Symlinked to `/usr/local/bin` after install:

```bash
ai-key-unlock        # unlock bundle, default 2h TTL
ai-key-unlock 90     # 90 minutes (bare number = minutes)
ai-key-unlock 90m    # same; also: 2h, 30s
ai-key-lock          # unload both managed keys immediately
ai-key-status        # which keys loaded? remaining TTL?
```

Optional path overrides:

```bash
export AI_KEY_PATH=~/.ssh/id_ed25519_ai      # default
export AI_GIT_KEY_PATH=~/.ssh/id_ed25519     # default; omit file to skip git key
export AI_KEY_TTL_SECONDS=7200               # default 2h
```

### Other shells / AI tools

For any **new shell** (Grok, Gemini CLI, Antigravity, VS Code terminals, etc.) to inherit the agent automatically, add this line to `~/.bashrc`:

```bash
# Auto-load SSH agent env (written by ai-key-unlock)
[[ -r "$HOME/.ssh/ai-key-agent.sh" ]] && source "$HOME/.ssh/ai-key-agent.sh"
```

> [!IMPORTANT]
> Without this line, AI tool sessions spawn without `SSH_AUTH_SOCK` set, causing `git push` and SSH commands to prompt for the key passphrase even when the agent is already running with the key loaded.

To verify manually or in a one-off shell:

```bash
source ~/.ssh/ai-key-agent.sh
ssh -T git@github.com
git -C /opt/dev/homelab_repo fetch
```

## 3. Cron (watchdog)

```
*/5 * * * * /opt/dev/homelab_repo/nodes/ai-tools/services/ai-ssh-key/ai-key-ttl-watchdog.sh >> /var/log/ai-key-ttl.log 2>&1
```

## 4. One-time install on ai-tools

```bash
REPO=/opt/dev/homelab_repo/nodes/ai-tools/services/ai-ssh-key
chmod 755 "$REPO"/ai-key-*.sh
chmod 644 "$REPO"/common.sh

ln -sfn "$REPO/ai-key-unlock.sh"  /usr/local/bin/ai-key-unlock
ln -sfn "$REPO/ai-key-lock.sh"    /usr/local/bin/ai-key-lock
ln -sfn "$REPO/ai-key-status.sh"  /usr/local/bin/ai-key-status

# Remove old MikroTik-era names if present:
#   rm -f /usr/local/bin/mikrotik-ai-{unlock,lock,status}

touch /var/log/ai-key-ttl.log
```

## 5. Files

| File | Purpose |
|------|---------|
| `common.sh` | Paths, agent helpers, multi-key bundle, TTL |
| `ai-key-unlock.sh` | `ssh-add` each managed key + TTL state |
| `ai-key-lock.sh` | `ssh-add -d` for each managed key |
| `ai-key-status.sh` | Per-key loaded status + TTL |
| `ai-key-ttl-watchdog.sh` | Cron: unload all after TTL |

## 6. Security notes

- Two **different** private keys (lab vs git); only unlock UX is shared.
- Both should be **passphrase-protected** at rest.
- TTL unloads **both**; lock unloads **both**.
- State and agent env files are mode `600`. Use `ai-key-agent.sh`, never `*.env` for the agent export (sandbox tools often break `**/*.env`).
- Prefer `ai-key-unlock` over bare `ssh-add` so the watchdog tracks TTL.
- Authorising the God Mode public key on more hosts increases blast radius while unlocked — keep TTL short.
