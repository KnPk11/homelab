# Homelab Watch — Telegram doorbell

> [!NOTE]
> #Telegram #Security #Monitoring
>
> **Host:** `ops` (CT 112). Same bot is used by CrowdSec, PAM, canaries.

Runtime file: `/srv/homelab-watch/telegram.env` (mode `600`). Git holds `telegram.env.example` and the SOPS-encrypted `telegram.env` (Master Admin + `ai-tools` keys). Decrypt from `ai-tools` (`sops-key-unlock`):

```bash
# On ai-tools after unlocking Master key:
sops -d /opt/dev/homelab_repo/nodes/ops/services/homelab-watch/telegram.env \
  | ssh ops 'install -d -m 700 /srv/homelab-watch && cat > /srv/homelab-watch/telegram.env && chmod 600 /srv/homelab-watch/telegram.env'
```

Test:

```bash
set -a
# shellcheck source=/dev/null
. /srv/homelab-watch/telegram.env
set +a
curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=Homelab Watch is online."
```

Channel: add `@HomelabWatchBot` as **admin** with **Post messages** only (do this from a trusted Telegram session, usually the phone). Do not add the bot as a subscriber.
