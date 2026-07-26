> [!NOTE]
> **Tags:** #MikroTik #SSH #Security #Agent

# MikroTik Remote Access Setup Guide

Secure SSH access for the automation agent (live: user `svc_ai` or `svc_backup` on `ai-tools` / `[AGENT-CONTAINER-IP]`) to the MikroTik router.

## Intent

| Source | SSH to router |
|--------|----------------|
| Main LAN / WireGuard (`LAN` interface list) | Yes (rate-limited) |
| Homelab / guest (`Untrusted`) | **No** |
| Exception: agent container | **Yes** (explicit allow) |
| WAN | Port knock only (see `port-knocking.md`) |

## 1. User Creation

```bash
/user add name=[AGENT-USER] group=full comment="CLI Agent"
```

> **Note:** The architecture uses two users: `svc_backup` (read-only, passwordless) and `svc_ai` (full admin, passphrase-protected key).

## 2. SSH Key Authentication

```bash
/file add name=[AGENT-USER].pub contents="[AGENT-PUBLIC-KEY]"
/user ssh-keys import public-key-file=[AGENT-USER].pub user=[AGENT-USER]
/file remove [AGENT-USER].pub
```

## 3. Firewall Authorisation

The agent runs on an **untrusted** segment (e.g. homelab), not the trusted LAN interface list. General “SSH from LAN” and “drop everything else” rules will **not** let it through.

Add an explicit **input** allow for that host’s SSH **above** your SSH drop / “not from LAN” rules:

```bash
/ip firewall filter add chain=input action=accept protocol=tcp \
    src-address=[AGENT-CONTAINER-IP] dst-port=22 \
    comment="Agent SSH from untrusted host" place-before=[DROP-RULE-INDEX]
```

Place it **before** any rule that drops remaining SSH or non-LAN input, or the agent will never connect.

## 4. Connection Verification

```bash
ssh -i /root/.ssh/id_ed25519_ai [AGENT-USER]@[ROUTER-IP] "/ip firewall filter print"
```

## 5. Operational unlock on ai-tools (TTL)

Router admin (`svc_ai`) uses the **same** passphrase-protected God Mode key as other privileged targets: `~/.ssh/id_ed25519_ai`. That key is also trusted on LXCs/VMs — it is **not** MikroTik-only.

On **ai-tools**, unlock with the host-wide TTL helpers (default **1 hour**):

```bash
ai-key-unlock
ai-key-status
source ~/.ssh/ai-key-agent.sh
ssh 192.168.88.1 '/system identity print'
ai-key-lock    # when finished (or wait for TTL)
```

## 6. Security Notes (current)

| Item | Value |
|------|--------|
| User | `[AGENT-USER]` (live: `svc_ai` / `svc_backup`) |
| Group | `full` (for `svc_ai`), `read` (for `svc_backup`) |
| Auth | SSH key (Ed25519); God Mode key is passphrase-protected |
| Source IP | `[AGENT-CONTAINER-IP]` (live: ai-tools) |
| Port | 22 |
| Admin key ops | Host-wide TTL unlock on ai-tools (`ai-key-*`, default 1h) — see §5 |

Backup cron: `capture-mikrotik-config.sh` uses `ROUTER_SSH_USER` (default `svc_backup`) and is **independent** of the God Mode TTL unlock.
