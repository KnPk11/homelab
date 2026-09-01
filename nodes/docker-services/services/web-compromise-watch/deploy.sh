#!/usr/bin/env bash
# =============================================================================
# deploy.sh — web-compromise-watch (docker-services)
# Version: 1.0
# Date: 2026-09-01
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SHARED="${SCRIPT_DIR}/../../../../shared/observability/web-compromise-watch"
if [[ ! -d "$SHARED" ]]; then
  SHARED="/opt/homelab-repo/shared/observability/web-compromise-watch"
fi

install -d -m 755 /srv/web-compromise-watch /srv/homelab-watch /var/lib/web-compromise-watch
if [[ ! -f /srv/homelab-watch/telegram.env ]]; then
  echo "Error: /srv/homelab-watch/telegram.env missing (BOT_TOKEN + CHAT_ID)."
  exit 1
fi
chmod 600 /srv/homelab-watch/telegram.env
if [[ ! -f /srv/web-compromise-watch/exec-watch.env ]]; then
  cp "$SCRIPT_DIR/exec-watch.env.example" /srv/web-compromise-watch/exec-watch.env
  chmod 600 /srv/web-compromise-watch/exec-watch.env
fi
if [[ ! -f /srv/web-compromise-watch/docker-events.env ]]; then
  cp "$SCRIPT_DIR/docker-events.env.example" /srv/web-compromise-watch/docker-events.env
  chmod 600 /srv/web-compromise-watch/docker-events.env
fi

install -m 755 "$SHARED/telegram-send.sh" /usr/local/sbin/homelab-watch-send
install -m 755 "$SHARED/exec-watch.sh" /usr/local/sbin/web-compromise-exec-watch
install -m 755 "$SHARED/docker-events-watch.py" /usr/local/sbin/web-compromise-docker-events
install -m 644 "$SHARED/exec-watch.service" /etc/systemd/system/web-compromise-exec-watch.service
install -m 644 "$SHARED/docker-events-watch.service" /etc/systemd/system/web-compromise-docker-events.service

# Snapshot currently published host ports so existing stacks are not "new".
if [[ ! -s /var/lib/web-compromise-watch/ports.baseline ]]; then
  python3 - <<'PY'
import json, subprocess
from pathlib import Path
ids = subprocess.check_output(["docker", "ps", "-q"], text=True).split()
ports = set()
for cid in ids:
    d = json.loads(subprocess.check_output(["docker", "inspect", cid], text=True))[0]
    binds = (d.get("HostConfig") or {}).get("PortBindings") or {}
    for maps in binds.values():
        if not maps:
            continue
        for m in maps:
            hp = (m or {}).get("HostPort") or ""
            if hp:
                ports.add(hp)
Path("/var/lib/web-compromise-watch/ports.baseline").write_text(
    "\n".join(sorted(ports, key=lambda p: (len(p), p))) + ("\n" if ports else "")
)
print(f"Wrote port baseline ({len(ports)} ports)")
PY
fi

systemctl daemon-reload
systemctl enable --now web-compromise-exec-watch.service web-compromise-docker-events.service
systemctl is-active web-compromise-exec-watch.service web-compromise-docker-events.service
echo "Deployment complete."
echo "After an intentional new publish: rebuild /var/lib/web-compromise-watch/ports.baseline and restart web-compromise-docker-events."
