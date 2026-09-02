#!/usr/bin/env bash
# =============================================================================
# deploy.sh — web-compromise-watch (shared; run on the target host)
# Version: 1.1
# Date: 2026-09-02
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
HOST="$(hostname -s)"
REPO_DIR="/opt/homelab-repo/shared/observability/web-compromise-watch"
if [[ ! -d "$REPO_DIR" ]]; then
  REPO_DIR="$SCRIPT_DIR"
fi

install -d -m 755 /srv/web-compromise-watch /var/lib/web-compromise-watch
install -d -m 700 /srv/homelab-watch

if [[ -r /srv/homelab-watch/telegram.env && -s /srv/homelab-watch/telegram.env ]]; then
  chmod 600 /srv/homelab-watch/telegram.env
elif [[ -r /etc/ssh/telegram.env && -s /etc/ssh/telegram.env ]]; then
  install -m 600 /etc/ssh/telegram.env /srv/homelab-watch/telegram.env
else
  echo "Error: need /srv/homelab-watch/telegram.env or /etc/ssh/telegram.env" >&2
  exit 1
fi

# Host profiles: do not watch login-user bash/python (uid 1000 = k on lab-vm/scratch-pc).
write_exec_env() {
  local dest=/srv/web-compromise-watch/exec-watch.env
  [[ -f "$dest" ]] && return 0
  case "$HOST" in
    reverse-proxy)
      cat >"$dest" <<'EOF'
WATCH_UIDS=999
WATCH_COMMS=sh,bash,dash,nc,ncat,netcat,socat,python,python3,perl
INTERVAL=5
RATE_SEC=60
TELEGRAM_ENV=/srv/homelab-watch/telegram.env
TELEGRAM_SEND=/usr/local/sbin/homelab-watch-send
EOF
      ;;
    docker-services)
      cat >"$dest" <<'EOF'
WATCH_CGROUP_REGEX=docker
WATCH_COMMS=nc,ncat,netcat,socat
INTERVAL=5
RATE_SEC=60
TELEGRAM_ENV=/srv/homelab-watch/telegram.env
TELEGRAM_SEND=/usr/local/sbin/homelab-watch-send
EOF
      ;;
    *)
      # lab-vm, scratch-pc, and other DIY web hosts: reverse-shell tools only.
      cat >"$dest" <<'EOF'
WATCH_COMMS=nc,ncat,netcat,socat
ALLOW_ANY_UID=1
INTERVAL=5
RATE_SEC=60
TELEGRAM_ENV=/srv/homelab-watch/telegram.env
TELEGRAM_SEND=/usr/local/sbin/homelab-watch-send
EOF
      ;;
  esac
  chmod 600 "$dest"
}

write_docker_env() {
  local dest=/srv/web-compromise-watch/docker-events.env
  [[ -f "$dest" ]] && return 0
  cat >"$dest" <<'EOF'
TELEGRAM_ENV=/srv/homelab-watch/telegram.env
TELEGRAM_SEND=/usr/local/sbin/homelab-watch-send
PORTS_BASELINE=/var/lib/web-compromise-watch/ports.baseline
EOF
  chmod 600 "$dest"
}

write_exec_env

ln -sfn "$REPO_DIR/telegram-send.sh" /usr/local/sbin/homelab-watch-send
ln -sfn "$REPO_DIR/exec-watch.sh" /usr/local/sbin/web-compromise-exec-watch
ln -sfn "$REPO_DIR/docker-events-watch.py" /usr/local/sbin/web-compromise-docker-events
install -m 644 "$REPO_DIR/exec-watch.service" /etc/systemd/system/web-compromise-exec-watch.service
install -m 644 "$REPO_DIR/docker-events-watch.service" /etc/systemd/system/web-compromise-docker-events.service

systemctl daemon-reload
systemctl enable --now web-compromise-exec-watch.service

ENABLE_DOCKER=0
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  ENABLE_DOCKER=1
fi
if [[ "$ENABLE_DOCKER" == "1" ]]; then
  write_docker_env
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
  systemctl enable --now web-compromise-docker-events.service
  systemctl is-active web-compromise-docker-events.service
else
  systemctl disable --now web-compromise-docker-events.service 2>/dev/null || true
fi

systemctl is-active web-compromise-exec-watch.service
echo "Deployment complete on $HOST (docker-events=${ENABLE_DOCKER})."
