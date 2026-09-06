#!/usr/bin/env bash
# Occasional manual audit. You unlock God Mode; this snapshots, locks, then agy (or grok).
#   monthly-audit --light | --deep
# Not OpenClaw/Hermes. Homelab Watch only.
set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# shellcheck source=/dev/null
[[ -r /etc/default/monthly-audit ]] && . /etc/default/monthly-audit
REPO="${REPO:-/opt/dev/homelab_repo}"
SSH_CFG="${SSH_CFG:-$REPO/shared/ssh/config}"
SCHEMA="${SCHEMA:-$SCRIPT_DIR/digest.schema.json}"
PLAYBOOK="$REPO/docs/03_Maintenance/security-audit-playbook.md"
ENV_FILE="${TELEGRAM_ENV:-/etc/ssh/telegram.env}"
[[ -s "$ENV_FILE" ]] || ENV_FILE=/srv/homelab-watch/telegram.env
SNAP_ROOT=/var/lib/monthly-audit
PRIVATE_DOCS=/opt/dev/docs_private/security

LIGHT_HOSTS=(
  proxmox-host docker-services nas lab-vm reverse-proxy dns
  pulse vpns pbs k8s scratch-pc syslog
)
LYNIS_HOSTS=(
  docker-services nas lab-vm reverse-proxy ai-tools dns
  pulse vpns pbs k8s scratch-pc syslog
)

DEPTH=""
DO_LOCK=1
DO_LLM=1
DO_TELEGRAM=1
LLM="${AUDIT_LLM:-agy}"

usage() {
  cat <<EOF
Usage: monthly-audit [--light|--deep] [--llm agy|grok] [--no-lock] [--no-llm] [--no-telegram]

Unlock God Mode first (ai-key-unlock && source ~/.ssh/ai-key-agent.sh).

  --light        playbook monthly light (CrowdSec/Caddy, DSTNAT, keys, reboot, updates)
  --deep         light plus Lynis on guests and Docker Bench on docker-services
  --llm agy|grok  Antigravity (default) or Grok CLI. AUDIT_LLM in /etc/default/monthly-audit
  --no-lock      leave God Mode loaded (debug)
  --no-llm       stop after snapshot
  --no-telegram  print digest, do not POST
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --light) DEPTH=light; shift ;;
    --deep) DEPTH=deep; shift ;;
    --llm) LLM="${2:-}"; shift 2 ;;
    --no-lock) DO_LOCK=0; shift ;;
    --no-llm) DO_LLM=0; shift ;;
    --no-telegram) DO_TELEGRAM=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [[ -z "$DEPTH" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Depth? [l]ight / [d]eep: " ans
    case "${ans,,}" in
      d|deep) DEPTH=deep ;;
      l|light|"") DEPTH=light ;;
      *) echo "monthly-audit: unknown depth" >&2; exit 2 ;;
    esac
  else
    echo "monthly-audit: pass --light or --deep" >&2
    exit 2
  fi
fi

# shellcheck source=/dev/null
[[ -f "$HOME/.ssh/ai-key-agent.sh" ]] && source "$HOME/.ssh/ai-key-agent.sh"

ssh_cmd() {
  ssh -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 -o IdentitiesOnly=yes "$@"
}

need_unlock() {
  if ! ssh_cmd proxmox-host 'hostname' >/dev/null 2>&1; then
    echo "monthly-audit: God Mode not usable. Run: ai-key-unlock && source ~/.ssh/ai-key-agent.sh" >&2
    exit 1
  fi
}

log() { echo "monthly-audit: $*"; }

remote() {
  local host="$1" out="$2" rc=0
  shift 2
  ssh_cmd "$host" "$@" >"$out" 2>&1 || rc=$?
  if [[ "$rc" -eq 255 ]]; then
    echo "SSH_FAIL $host (no connection)" >>"$out"
    return 1
  fi
  return 0
}

clip() {
  local f="$1" n="${2:-200}"
  [[ -f "$f" ]] || return 0
  local lines
  lines=$(wc -l <"$f")
  if [[ "$lines" -gt "$n" ]]; then
    echo "... truncated to last $n of $lines lines ..."
    tail -n "$n" "$f"
  else
    cat "$f"
  fi
}

send_tg() {
  local text="$1"
  # shellcheck source=/dev/null
  set -a
  [[ -r "$ENV_FILE" ]] && . "$ENV_FILE"
  set +a
  local token="${BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
  local chat="${CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
  [[ -n "$token" && -n "$chat" ]] || { log "no telegram env"; return 1; }
  python3 - "$token" "$chat" "$text" <<'PY'
import sys, urllib.parse, urllib.request
token, chat, text = sys.argv[1], sys.argv[2], sys.argv[3]
# Telegram 4096; split if needed
chunks = []
while text:
    chunks.append(text[:3500])
    text = text[3500:]
for part in chunks:
    body = urllib.parse.urlencode({"chat_id": chat, "text": part}).encode()
    urllib.request.urlopen(
        urllib.request.Request(
            f"https://api.telegram.org/bot{token}/sendMessage",
            data=body,
            method="POST",
        ),
        timeout=15,
    ).read()
PY
}

SNAP="$SNAP_ROOT/$(date +%Y%m%d-%H%M%S)-$DEPTH"
mkdir -p "$SNAP"
chmod 700 "$SNAP_ROOT" "$SNAP"
ln -sfn "$SNAP" "$SNAP_ROOT/latest"
echo "$DEPTH" >"$SNAP/mode"

need_unlock
log "snapshot $DEPTH → $SNAP"

{
  echo "=== mode $DEPTH ==="
  date -u
  command -v ai-key-status >/dev/null && ai-key-status || true
  command -v sops-key-status >/dev/null && sops-key-status || true
} >"$SNAP/00-keys-status.txt"

# local ai-tools
{
  echo "=== OS ai-tools ==="
  hostname -s
  test -f /var/run/reboot-required && echo REBOOT_REQUIRED || echo reboot_not_flagged
  command -v needrestart >/dev/null && needrestart -b 2>/dev/null | grep NEEDRESTART-KSTA || true
  apt-get -s upgrade 2>/dev/null | tail -n 12 || true
} >"$SNAP/host-ai-tools.txt"

for h in "${LIGHT_HOSTS[@]}"; do
  log "light $h"
  remote "$h" "$SNAP/host-$h.txt" bash -s <<'EOS' || true
echo "=== OS $(hostname -s) ==="
test -f /var/run/reboot-required && echo REBOOT_REQUIRED || echo reboot_not_flagged
command -v needrestart >/dev/null && needrestart -b 2>/dev/null | grep NEEDRESTART-KSTA || true
if command -v pveversion >/dev/null; then pveversion -v 2>/dev/null | head -n 8; fi
apt-get -s upgrade 2>/dev/null | tail -n 12 || true
echo "=== native ==="
for u in caddy crowdsec fail2ban adguardhome openclaw hermes-gateway pulse smbd; do
  systemctl is-active "$u" >/dev/null 2>&1 && echo "$u: $(systemctl is-active "$u")"
done
EOS
done

log "crowdsec + caddy reverse-proxy"
remote reverse-proxy "$SNAP/crowdsec-caddy.txt" bash -s <<'EOS' || true
echo "=== crowdsec ==="
systemctl is-active crowdsec
cscli bouncers list 2>/dev/null || true
cscli machines list 2>/dev/null || true
cscli decisions list -l 15 2>/dev/null || true
echo "=== caddy ==="
systemctl is-active caddy
caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -n 20 || true
echo "=== site blocks (names only) ==="
grep -E '^[A-Za-z0-9.*_-]+ \{' /etc/caddy/Caddyfile 2>/dev/null | head -n 80 || true
EOS

log "docker-services images + secret perms (modes only)"
remote docker-services "$SNAP/docker-images.txt" bash -s <<'EOS' || true
echo "=== docker ps ==="
docker ps --format '{{.Names}} {{.Image}} {{.Status}}' 2>/dev/null | head -n 80
echo "=== secret file modes (no contents) ==="
find /srv -maxdepth 3 \( -name '*.env' -o -name '*.secret' -o -name '*.pwd' \) \
  -printf '%m %u:%g %p\n' 2>/dev/null | head -n 50
EOS

log "mikrotik dstnat + resource (svc_backup job key; God Mode router is not used here)"
remote mikrotik-backup "$SNAP/mikrotik.txt" \
  '/system resource print; /system package update print; /ip service print; /ip firewall nat print where chain=dstnat' || true

log "git hygiene (names only)"
{
  echo "=== git status (homelab_repo) ==="
  git -C "$REPO" status --porcelain | head -n 40
  echo "=== tracked paths matching env/secret (names) ==="
  git -C "$REPO" ls-files | grep -Ei '\.(env|secret|pwd)$|credentials' | head -n 40 || true
} >"$SNAP/git-hygiene.txt"

if [[ -d "$PRIVATE_DOCS" ]]; then
  {
    echo "=== private baseline filenames ==="
    find "$PRIVATE_DOCS" -maxdepth 2 -type f -name '*.md' -printf '%f\n' 2>/dev/null | sort
    for f in lynis-audit.md mikrotik-firewall-audit.md linux-host-hygiene.md; do
      p="$PRIVATE_DOCS/$f"
      if [[ -f "$p" ]]; then
        echo "----- $f (first 80 lines, no secrets expected) -----"
        head -n 80 "$p"
      fi
    done
  } >"$SNAP/baselines-skim.txt"
fi

if [[ "$DEPTH" == deep ]]; then
  for h in "${LYNIS_HOSTS[@]}"; do
    log "lynis $h"
    if [[ "$h" == "ai-tools" ]]; then
      if command -v lynis >/dev/null; then
        lynis audit system --quick --no-log >/dev/null 2>&1 || true
        grep -E 'warning|suggestion' /var/log/lynis-report.dat 2>/dev/null | tail -n 80 \
          >"$SNAP/lynis-$h.txt" || echo "no lynis-report.dat" >"$SNAP/lynis-$h.txt"
      else
        echo "lynis not installed" >"$SNAP/lynis-$h.txt"
      fi
      continue
    fi
    remote "$h" "$SNAP/lynis-$h.txt" bash -s <<'EOS' || true
if ! command -v lynis >/dev/null; then echo "lynis not installed"; exit 0; fi
lynis audit system --quick --no-log >/dev/null
grep -E 'warning|suggestion' /var/log/lynis-report.dat 2>/dev/null | tail -n 80 || echo "no report"
EOS
  done
  log "docker bench"
  remote docker-services "$SNAP/docker-bench.txt" bash -s <<'EOS' || true
dir=""
for d in /opt/docker-bench-security "$HOME/docker-bench-security"; do
  [[ -x "$d/docker-bench-security.sh" ]] && dir=$d && break
done
if [[ -z "$dir" ]]; then echo "docker-bench-security not found"; exit 0; fi
cd "$dir"
sh docker-bench-security.sh 2>/dev/null | grep -E '\[WARN\]|\[FAIL\]|\[INFO\] Score' | tail -n 120
EOS
fi

log "snapshot complete"

if [[ "$DO_LOCK" -eq 1 ]]; then
  log "locking God Mode"
  ai-key-lock || true
else
  log "skipping lock (--no-lock)"
fi

PROMPT="$SNAP/prompt.txt"
{
  echo "You are tagging a read-only homelab security snapshot."
  echo "Output MUST match the JSON schema. No essays. No secret values, tokens, keys, .env contents, passwords."
  echo "Do not invent hosts. Empty arrays are required when there is nothing to say."
  echo "Severity: fix_now = active exposure / broken control; track = defer; needs_baseline_update = new exception not in private baselines; accepted = still matches baseline."
  echo "Mode: $DEPTH"
  echo "Playbook (excerpt — follow monthly-light unless mode is deep):"
  echo
  # keep playbook bounded
  python3 - "$PLAYBOOK" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
print(text[:24000])
if len(text) > 24000:
    print("\n... playbook truncated ...")
PY
  echo
  echo "===== SNAPSHOT FILES ====="
  find "$SNAP" -type f ! -name prompt.txt ! -name digest.json ! -name digest.md | sort | while read -r f; do
    echo
    echo "----- ${f#"$SNAP"/} -----"
    clip "$f" 220
  done
} >"$PROMPT"
chmod 600 "$PROMPT"

if [[ "$DO_LLM" -ne 1 ]]; then
  log "skipping LLM. snapshot: $SNAP"
  exit 0
fi

DIGEST_JSON="$SNAP/digest.json"
LLM_ERR="$SNAP/llm.err"
log "running ${LLM} (keys already locked)"
set +e
case "$LLM" in
  agy|antigravity)
    if ! command -v agy >/dev/null; then
      log "agy (Antigravity) missing; snapshot left at $SNAP"
      exit 1
    fi
    # plan + sandbox: no SSH after lock. Do not pass --dangerously-skip-permissions.
    agy_args=(agy --print --json-schema "$SCHEMA" --output-format json --mode plan --sandbox --disable-slash-commands)
    if [[ -n "${AUDIT_MODEL:-}" ]]; then
      agy_args+=(--model "$AUDIT_MODEL")
    fi
    agy_args+=(--prompt "$(cat "$PROMPT")")
    "${agy_args[@]}" >"$DIGEST_JSON" 2>"$LLM_ERR"
    ;;
  grok)
    if ! command -v grok >/dev/null; then
      log "grok CLI missing; snapshot left at $SNAP"
      exit 1
    fi
    grok --prompt-file "$PROMPT" \
      --json-schema "$(cat "$SCHEMA")" \
      --max-turns 1 \
      --no-subagents \
      --disable-web-search \
      --output-format json \
      >"$DIGEST_JSON" 2>"$LLM_ERR"
    ;;
  *)
    log "unknown --llm $LLM (use agy or grok)"
    exit 2
    ;;
esac
grc=$?
set -e
if [[ "$grc" -ne 0 || ! -s "$DIGEST_JSON" ]]; then
  log "${LLM} failed (rc=$grc). See $LLM_ERR"
  if [[ "$DO_TELEGRAM" -eq 1 ]]; then
    send_tg "📋 Audit failed
mode: $DEPTH
llm: $LLM rc $grc
snapshot: $SNAP" || true
  fi
  exit 1
fi

DIGEST_MD="$SNAP/digest.md"
python3 - "$DIGEST_JSON" "$DEPTH" >"$DIGEST_MD" <<'PY'
import json, sys
raw = open(sys.argv[1], encoding="utf-8").read()
mode = sys.argv[2]
data = json.loads(raw)
# grok --output-format json may wrap
if isinstance(data, dict) and "fix_now" not in data:
    for k in ("data", "result", "output", "message"):
        if isinstance(data.get(k), dict) and "fix_now" in data[k]:
            data = data[k]
            break
        if isinstance(data.get(k), str):
            try:
                inner = json.loads(data[k])
                if isinstance(inner, dict) and "fix_now" in inner:
                    data = inner
                    break
            except json.JSONDecodeError:
                pass
label = "deep" if mode == "deep" else "monthly light"
lines = [f"Homelab audit — {label}", ""]

def bucket(title, key, fields):
    items = data.get(key) or []
    lines.append(f"{title} ({len(items)})")
    if not items:
        lines.append("- (none)")
    else:
        for it in items:
            if key == "accepted":
                ctrl = it.get("control") or "?"
                fact = it.get("fact") or ""
                extra = f" — {fact}" if fact else ""
                lines.append(f"- {ctrl}{extra}")
            else:
                host = it.get("host") or "?"
                fact = it.get("fact") or ""
                why = it.get("why") or ""
                extra = f" — {why}" if why else ""
                lines.append(f"- {host}: {fact}{extra}")
    lines.append("")

bucket("FIX NOW", "fix_now", None)
bucket("TRACK", "track", None)
bucket("NEEDS BASELINE UPDATE", "needs_baseline_update", None)
bucket("ACCEPTED", "accepted", None)
print("\n".join(lines).rstrip())
PY
chmod 600 "$DIGEST_MD" "$DIGEST_JSON"

log "digest written $DIGEST_MD"
if [[ "$DO_TELEGRAM" -eq 1 ]]; then
  send_tg "$(cat "$DIGEST_MD")"
  log "telegram sent"
else
  cat "$DIGEST_MD"
fi
echo "snapshot: $SNAP"
