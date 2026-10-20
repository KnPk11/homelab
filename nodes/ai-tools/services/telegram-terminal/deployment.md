# AI Terminal Suite — Deployment Runbook

> [!NOTE]
> #Telegram #Antigravity #Grok #AiAgent #AiTools #RemoteAccess
>
> **Host:** `ai-tools` | **Runtime:** `/opt/telegram-terminal`  
> **Docs:** [Architecture & Setup](../../../docs/02_Services/telegram-terminal/setup.md) · [Security Model](../../../docs/02_Services/telegram-terminal/security.md)

## 1. Overview

Operational bootstrap runbook for the headless Telegram daemon bridging mobile devices to Antigravity (`agy`) and Grok (`grok`) on `ai-tools`. Full feature documentation, mobile ergonomics, and command reference live in the [service setup guide](../../../docs/02_Services/telegram-terminal/setup.md).

## 2. Deployment & Recovery

1. **Clone Application & Dependencies**:
   ```bash
   git clone git@github.com:KnPk11/ai-telegram-suite.git /opt/telegram-terminal
   cd /opt/telegram-terminal
   npm install
   ```

2. **Configure Environment**:
   Copy template and populate secrets in `/opt/telegram-terminal/.env` (excluded from Git):
   ```bash
   cp /opt/dev/homelab_repo/nodes/ai-tools/services/telegram-terminal/terminal.env.example /opt/telegram-terminal/.env
   chmod 600 /opt/telegram-terminal/.env
   # Set BOT_TOKEN and ALLOWED_CHAT_IDS
   ```

3. **Install & Start Service**:
   ```bash
   cp /opt/dev/homelab_repo/nodes/ai-tools/services/telegram-terminal/telegram-terminal.service /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable --now telegram-terminal
   ```

## 3. Operational Commands

```bash
# Service status and logs
systemctl status telegram-terminal
journalctl -u telegram-terminal -f

# Restart daemon after updates
systemctl restart telegram-terminal
```

## 4. Files

| File | Purpose |
| :--- | :--- |
| `nodes/ai-tools/services/telegram-terminal/telegram-terminal.service` | Production systemd service unit |
| `nodes/ai-tools/services/telegram-terminal/terminal.env.example` | Sanitised environment template |
| `/opt/telegram-terminal/.env` | Local runtime credentials (**not in Git**) |
| [`KnPk11/ai-telegram-suite`](https://github.com/KnPk11/ai-telegram-suite) | Upstream application repository |
