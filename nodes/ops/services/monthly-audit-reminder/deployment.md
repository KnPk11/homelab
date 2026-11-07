# Monthly Audit Reminder — Deployment Guide

> [!NOTE]
> **Tags:** #Monitoring #Telegram #Security #Audit
> **Host:** `ops` (CT 112) | **Schedule:** Every Sunday 09:00

## 1. Overview

This systemd timer sends a weekly Telegram nudge to remind the operator to run `monthly-audit --light` or `monthly-audit --deep` from `ai-tools`.

The reminder job itself runs completely unprivileged on `ops` without SSH keys, God Mode, or LLM access. It only requires access to `/srv/homelab-watch/telegram.env`.

---

## 2. Installation

```bash
sudo /opt/homelab-repo/nodes/ops/services/monthly-audit-reminder/deploy.sh
```

---

## 3. Testing

Test the reminder manually without updating the last-sent timestamp:

```bash
/usr/local/sbin/monthly-audit-reminder --dry-run
```

Or trigger a test notification to Telegram:

```bash
/usr/local/sbin/monthly-audit-reminder --force
```

---

## 4. Files

| File | Purpose |
|------|---------|
| `reminder.sh` | Nudge script triggered by systemd service |
| `reminder.service` | Oneshot systemd service definition |
| `reminder.timer` | Calendar timer (every Sunday 09:00) |
| `deploy.sh` | Automated installer script |
| `/srv/homelab-watch/telegram.env` | Telegram bot credentials |
