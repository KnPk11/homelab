> [!NOTE]
> **Tags:** #MikroTik #SSH #Security #Agent

# MikroTik Remote Access Setup Guide

Secure SSH access for the automation agent (live: user `gemini` on `ai-tools` / `[AGENT-CONTAINER-IP]`) to the MikroTik router.

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

> **Future:** product-agnostic name + two users (ops read-only / admin full disabled by default). See security audit M5 / mikrotik-backup CHANGELOG.

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
ssh -i /root/.ssh/id_ed25519 [AGENT-USER]@[ROUTER-IP] "/ip firewall filter print"
```

## 5. Security Notes (current)

| Item | Value |
|------|--------|
| User | `[AGENT-USER]` (live: `gemini`) |
| Group | `full` (planned least-privilege later) |
| Auth | SSH key (Ed25519) |
| Source IP | `[AGENT-CONTAINER-IP]` |
| Port | 22 |

Backup cron: `capture-mikrotik-config.sh` uses `ROUTER_SSH_USER` (default `gemini`).
