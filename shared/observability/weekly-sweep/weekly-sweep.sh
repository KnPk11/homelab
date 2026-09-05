#!/usr/bin/env bash
# Weekly 10-minute sweep. Local checks + Homelab Watch. No LLM.
# 🔴 red = broken control. 🟠 amber = maintenance. 🟢 silent.
set -euo pipefail

CONF="${WEEKLY_SWEEP_CONF:-/etc/default/weekly-sweep}"
# shellcheck source=/dev/null
[[ -r "$CONF" ]] && . "$CONF"

CHECKS="${CHECKS:-reboot}"
ENV_FILE="${TELEGRAM_ENV:-}"
if [[ -z "$ENV_FILE" ]]; then
  if [[ -s /srv/homelab-watch/telegram.env ]]; then
    ENV_FILE=/srv/homelab-watch/telegram.env
  else
    ENV_FILE=/etc/ssh/telegram.env
  fi
fi
DSTNAT_PORTS="${DSTNAT_PORTS:-/var/lib/weekly-sweep/dstnat.ports}"
LURES_LIST="${LURES_LIST:-/var/lib/weekly-sweep/lures.list}"
WG_PORT="${WG_PORT:-51821}"
CROWDSEC_BOUNCERS="${CROWDSEC_BOUNCERS:-mikrotik-bouncer,firewall-bouncer}"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

HOST="$(hostname -s 2>/dev/null || hostname)"
levels=()
titles=()
details=()

log() { echo "weekly-sweep: $*"; }

add() {
  levels+=("$1")
  titles+=("$2")
  details+=("$3")
}

send() {
  local text="$1"
  [[ "$DRY_RUN" -eq 1 ]] && { log "dry-run telegram:"; printf '%s\n' "$text"; return 0; }
  # shellcheck source=/dev/null
  set -a
  [[ -r "$ENV_FILE" ]] && . "$ENV_FILE"
  set +a
  local token="${BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
  local chat="${CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
  [[ -n "$token" && -n "$chat" ]] || { log "no telegram env, skip send"; return 0; }
  python3 - "$token" "$chat" "$text" <<'PY' || log "telegram send failed"
import sys, time, urllib.error, urllib.parse, urllib.request
token, chat, text = sys.argv[1], sys.argv[2], sys.argv[3]
body = urllib.parse.urlencode({"chat_id": chat, "text": text}).encode()
url = f"https://api.telegram.org/bot{token}/sendMessage"
err = None
for attempt in range(4):
    try:
        urllib.request.urlopen(
            urllib.request.Request(url, data=body, method="POST"),
            timeout=8,
        ).read()
        sys.exit(0)
    except urllib.error.HTTPError as e:
        err = e
        if e.code != 429 or attempt == 3:
            raise
        time.sleep(2 ** (attempt + 1))
if err:
    raise err
PY
}

check_reboot() {
  local flag=0 ksta="" kcur
  kcur="$(uname -r 2>/dev/null || echo unknown)"
  [[ -f /var/run/reboot-required ]] && flag=1
  if command -v needrestart >/dev/null 2>&1; then
    ksta="$(needrestart -b 2>/dev/null | awk -F': ' '/NEEDRESTART-KSTA/ {print $2; exit}' || true)"
  fi
  if [[ "$flag" -eq 1 || "$ksta" == "2" ]]; then
    local d="running kernel: ${kcur}"
    [[ "$flag" -eq 1 ]] && d+=$'\nflag: /var/run/reboot-required'
    [[ -n "$ksta" ]] && d+=$'\nneedrestart KSTA: '"$ksta"' (2=stale kernel)'
    add amber "reboot required on ${HOST}" "$d"
  fi
}

check_crowdsec() {
  if ! command -v cscli >/dev/null 2>&1; then
    add red "crowdsec tools missing on ${HOST}" "cscli not in PATH. Unit cannot be verified."
    return
  fi
  local state
  state="$(systemctl is-active crowdsec 2>/dev/null || true)"
  if [[ "$state" != "active" ]]; then
    add red "crowdsec unit not active on ${HOST}" "systemctl is-active: ${state:-unknown}"$'\n'"expected bouncers: ${CROWDSEC_BOUNCERS}"
  fi
  local out rc=0
  out="$(python3 - "$CROWDSEC_BOUNCERS" <<'PY'
import json, subprocess, sys
want = [x.strip() for x in sys.argv[1].split(",") if x.strip()]
raw = subprocess.check_output(["cscli", "bouncers", "list", "-o", "json"], text=True)
rows = json.loads(raw or "[]")
by = {row.get("name"): row for row in rows}
lines = []
bad = False
for name in want:
    row = by.get(name)
    if row is None:
        lines.append(f"{name}: MISSING")
        bad = True
        continue
    revoked = bool(row.get("revoked"))
    pull = row.get("last_pull") or "never"
    mark = "revoked" if revoked else "ok"
    if revoked:
        bad = True
    lines.append(f"{name}: {mark}, last pull {pull}")
if bad:
    print("\n".join(lines))
    sys.exit(1)
PY
)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    add red "crowdsec bouncers on ${HOST}" "${out:-bouncer check failed}"
  fi
}

check_dstnat() {
  local ident="${ROUTER_SSH_IDENTITY:-$HOME/.ssh/id_ed25519_mt_backup}"
  local user="${ROUTER_SSH_USER:-svc_backup}"
  local rhost="${ROUTER_SSH_HOST:-192.168.88.1}"
  if [[ ! -f "$ident" ]]; then
    add red "dstnat job key missing" "need passphrase-less ${ident}"$'\n'"same key as MikroTik config capture"
    return
  fi
  if [[ ! -f "$DSTNAT_PORTS" ]]; then
    add red "dstnat allowlist missing" "expected file: ${DSTNAT_PORTS}"
    return
  fi
  local tmp rc=0
  tmp="$(mktemp)"
  if ! ssh -i "$ident" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 \
      "${user}@${rhost}" '/ip firewall nat export where chain=dstnat; /interface wireguard print' \
      >"$tmp" 2>/dev/null; then
    rm -f "$tmp"
    add red "dstnat router SSH failed" "user ${user} @ ${rhost}"$'\n'"job key ${ident}"
    return
  fi
  local report
  report="$(EXPECTED="$DSTNAT_PORTS" WG_PORT="$WG_PORT" python3 - "$tmp" <<'PY'
import json, os, re, sys
export = open(sys.argv[1], encoding="utf-8", errors="replace").read()
expected_path = os.environ["EXPECTED"]
wg_port = (os.environ.get("WG_PORT") or "").strip()
flat = re.sub(r"\\\s*\n\s*", "", export)
live = set()
for m in re.finditer(r"^add\s+(.+)$", flat, re.M):
    body = m.group(1)
    if re.search(r"\bdisabled=yes\b", body):
        continue
    if "chain=dstnat" not in body:
        continue
    port_m = re.search(r"dst-port=(\S+)", body)
    proto_m = re.search(r"protocol=(\S+)", body)
    if not port_m:
        continue
    port = port_m.group(1).rstrip("\\")
    proto = (proto_m.group(1) if proto_m else "tcp").rstrip("\\")
    live.add(f"{port}/{proto}")
want = set()
with open(expected_path, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        want.add(line)
wg_found = None
wg_m = re.search(r"listen-port=(\d+)", export)
if wg_m:
    wg_found = wg_m.group(1)
print(json.dumps({
    "extra": sorted(live - want),
    "missing": sorted(want - live),
    "live": sorted(live),
    "wg_found": wg_found,
    "wg_want": wg_port or None,
}))
PY
)" || rc=$?
  rm -f "$tmp"
  if [[ "$rc" -ne 0 || -z "${report:-}" ]]; then
    add red "dstnat parse failed" "could not read router NAT export"
    return
  fi
  local envf
  envf="$(mktemp)"
  python3 - "$report" <<'PY' >"$envf"
import json, shlex, sys
d = json.loads(sys.argv[1])
def csv(key):
    return " ".join(d.get(key) or [])
print("DST_EXTRA=" + shlex.quote(csv("extra")))
print("DST_MISSING=" + shlex.quote(csv("missing")))
print("DST_LIVE=" + shlex.quote(csv("live")))
print("WG_FOUND=" + shlex.quote(d.get("wg_found") or ""))
print("WG_WANT=" + shlex.quote(d.get("wg_want") or ""))
PY
  # shellcheck source=/dev/null
  . "$envf"
  rm -f "$envf"
  if [[ -n "${DST_EXTRA:-}" ]]; then
    add red "new WAN dstnat (not in allowlist)" "extra: ${DST_EXTRA}"$'\nlive: '"${DST_LIVE}"$'\nedit /var/lib/weekly-sweep/dstnat.ports if this is intended'
  fi
  if [[ -n "${DST_MISSING:-}" ]]; then
    add amber "expected WAN dstnat missing" "missing: ${DST_MISSING}"$'\nlive: '"${DST_LIVE}"$'\nupdate allowlist or restore the mapping'
  fi
  if [[ -n "${WG_WANT:-}" ]]; then
    if [[ -z "${WG_FOUND:-}" ]]; then
      add red "WireGuard listen-port missing" "want udp/${WG_WANT} on input, not dstnat"
    elif [[ "$WG_FOUND" != "$WG_WANT" ]]; then
      add red "WireGuard listen-port changed" "have ${WG_FOUND}, want ${WG_WANT}"
    fi
  fi
}

check_lures() {
  if [[ ! -s "$LURES_LIST" ]]; then
    add red "planted-file list missing on ${HOST}" "expected ${LURES_LIST}"$'\nre-run weekly-sweep rollout from ai-tools'
    return
  fi
  local missing=0 total=0
  while IFS= read -r path || [[ -n "$path" ]]; do
    path="${path%%#*}"
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"
    [[ -z "$path" ]] && continue
    total=$((total + 1))
    if [[ ! -e "$path" ]]; then
      missing=$((missing + 1))
      log "planted file missing: ${path}"
    fi
  done < "$LURES_LIST"
  if [[ "$total" -eq 0 ]]; then
    add red "planted-file list empty on ${HOST}" "${LURES_LIST} has no paths"
  elif [[ "$missing" -gt 0 ]]; then
    add red "planted files missing on ${HOST}" "${missing} of ${total} files gone"$'\npaths are in the journal on this host, not Telegram'
  fi
}

build_msg() {
  local i n_red=0 n_amber=0
  for i in "${!levels[@]}"; do
    case "${levels[$i]}" in
      red) n_red=$((n_red + 1)) ;;
      amber) n_amber=$((n_amber + 1)) ;;
    esac
  done
  local icon footer
  if [[ "$n_red" -gt 0 ]]; then
    icon="🔴"
    footer="Skip monthly AI until RED is empty."
  else
    icon="🟠"
    footer="Maintenance only. Monthly AI can still run."
  fi
  local msg
  msg="${icon} Weekly sweep
host: ${HOST}
checks: ${CHECKS}
red: ${n_red}  amber: ${n_amber}"
  if [[ "$n_red" -gt 0 ]]; then
    msg+=$'\n\nRED'
    for i in "${!levels[@]}"; do
      [[ "${levels[$i]}" == red ]] || continue
      msg+=$'\n- '"${titles[$i]}"
      if [[ -n "${details[$i]}" ]]; then
        while IFS= read -r line; do
          [[ -n "$line" ]] && msg+=$'\n  '"$line"
        done <<< "${details[$i]}"
      fi
    done
  fi
  if [[ "$n_amber" -gt 0 ]]; then
    msg+=$'\n\nAMBER'
    for i in "${!levels[@]}"; do
      [[ "${levels[$i]}" == amber ]] || continue
      msg+=$'\n- '"${titles[$i]}"
      if [[ -n "${details[$i]}" ]]; then
        while IFS= read -r line; do
          [[ -n "$line" ]] && msg+=$'\n  '"$line"
        done <<< "${details[$i]}"
      fi
    done
  fi
  msg+=$'\n\n'"$footer"
  printf '%s' "$msg"
}

IFS=',' read -r -a _checks <<< "$CHECKS"
for c in "${_checks[@]}"; do
  c="${c// /}"
  [[ -z "$c" ]] && continue
  case "$c" in
    reboot) check_reboot ;;
    crowdsec) check_crowdsec ;;
    dstnat) check_dstnat ;;
    lures) check_lures ;;
    *) log "unknown check $c" ;;
  esac
done

if [[ "${#levels[@]}" -eq 0 ]]; then
  log "green (${CHECKS})"
  exit 0
fi
msg="$(build_msg)"
log "notify ${#levels[@]} finding(s)"
send "$msg"
exit 0
