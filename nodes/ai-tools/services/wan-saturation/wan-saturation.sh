#!/usr/bin/env bash
# Poll MikroTik WAN rate; Homelab Watch if the pipe stays full.
# Uses mikrotik-backup (no God Mode). Not a DDoS classifier.
set -euo pipefail

# shellcheck source=/dev/null
[[ -r /etc/default/wan-saturation ]] && . /etc/default/wan-saturation

SSH_CFG="${SSH_CFG:-/opt/dev/homelab_repo/shared/ssh/config}"
WAN_IFACE="${WAN_IFACE:-pppoe-out1}"
RX_MBPS="${RX_MBPS:-900}"
TX_MBPS="${TX_MBPS:-110}"
FIRE_PCT="${FIRE_PCT:-85}"
CLEAR_PCT="${CLEAR_PCT:-70}"
SAMPLES="${SAMPLES:-2}"
STATE="${STATE:-/var/lib/wan-saturation/state}"
ENV_FILE="${TELEGRAM_ENV:-}"
if [[ -z "$ENV_FILE" ]]; then
  if [[ -s /srv/homelab-watch/telegram.env ]]; then
    ENV_FILE=/srv/homelab-watch/telegram.env
  else
    ENV_FILE=/etc/ssh/telegram.env
  fi
fi
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log() { echo "wan-saturation: $*"; }

send() {
  local text="$1"
  [[ "$DRY_RUN" -eq 1 ]] && { log "dry-run telegram:"; printf '%s\n' "$text"; return 0; }
  set -a
  # shellcheck source=/dev/null
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

mkdir -p "$(dirname "$STATE")"
chmod 700 "$(dirname "$STATE")" 2>/dev/null || true

if [[ ! "$WAN_IFACE" =~ ^[A-Za-z0-9._-]+$ ]]; then
  log "invalid WAN_IFACE"
  exit 2
fi

raw=""
rc=0
raw=$(ssh -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 mikrotik-backup \
  ":put [/interface monitor-traffic $WAN_IFACE as-value once]" 2>/dev/null) || rc=$?

payload=$(python3 - "$STATE" "$WAN_IFACE" "$RX_MBPS" "$TX_MBPS" \
  "$FIRE_PCT" "$CLEAR_PCT" "$SAMPLES" "$DRY_RUN" "$rc" "$raw" <<'PY'
import json, os, sys

state_path, iface = sys.argv[1], sys.argv[2]
rx_mbps, tx_mbps = float(sys.argv[3]), float(sys.argv[4])
fire_pct, clear_pct = float(sys.argv[5]), float(sys.argv[6])
samples = int(sys.argv[7])
dry = sys.argv[8] == "1"
ssh_rc = int(sys.argv[9])
raw = sys.argv[10].replace("\r", "").strip()

def load():
    try:
        with open(state_path, encoding="utf-8") as f:
            d = json.load(f)
        if isinstance(d, dict):
            return d
    except (OSError, json.JSONDecodeError):
        pass
    return {
        "rx_hot": 0, "rx_cool": 0, "rx_alarm": False,
        "tx_hot": 0, "tx_cool": 0, "tx_alarm": False,
        "ssh_fail": 0, "ssh_alarm": False,
    }

def save(d):
    if dry:
        return
    tmp = state_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(d, f)
        f.write("\n")
    os.replace(tmp, state_path)
    os.chmod(state_path, 0o600)

def fmt(bps):
    if bps >= 1_000_000_000:
        return f"{bps / 1_000_000_000:.2f} Gbps"
    if bps >= 1_000_000:
        return f"{bps / 1_000_000:.0f} Mbps"
    if bps >= 1_000:
        return f"{bps / 1_000:.1f} kbps"
    return f"{int(bps)} bps"

st = load()
msgs = []

if ssh_rc != 0 or not raw:
    st["ssh_fail"] = int(st.get("ssh_fail") or 0) + 1
    if st["ssh_fail"] >= samples and not st.get("ssh_alarm"):
        st["ssh_alarm"] = True
        msgs.append("🟠 WAN counters unread (mikrotik-backup)")
    save(st)
    if dry:
        print(f"STATUS ssh_fail rc={ssh_rc} fails={st['ssh_fail']}", file=sys.stderr)
    print(json.dumps(msgs, ensure_ascii=False))
    sys.exit(0)

kv = {}
for part in raw.split(";"):
    if "=" in part:
        k, v = part.split("=", 1)
        kv[k.strip()] = v.strip()
try:
    rx = int(float(kv["rx-bits-per-second"]))
    tx = int(float(kv["tx-bits-per-second"]))
except (KeyError, ValueError):
    print("parse-fail " + raw, file=sys.stderr)
    sys.exit(1)

st["ssh_fail"] = 0
if st.get("ssh_alarm"):
    st["ssh_alarm"] = False
    msgs.append("🟢 WAN counters readable again")

rx_fire = rx_mbps * 1_000_000 * fire_pct / 100
rx_clear = rx_mbps * 1_000_000 * clear_pct / 100
tx_fire = tx_mbps * 1_000_000 * fire_pct / 100
tx_clear = tx_mbps * 1_000_000 * clear_pct / 100


def streak(alarm_key, hot_key, cool_key, value, fire, clear):
    if value >= fire:
        st[hot_key] = int(st.get(hot_key) or 0) + 1
        st[cool_key] = 0
        if st[hot_key] >= samples and not st.get(alarm_key):
            st[alarm_key] = True
            return "fire"
    elif value <= clear:
        st[cool_key] = int(st.get(cool_key) or 0) + 1
        st[hot_key] = 0
        if st[cool_key] >= samples and st.get(alarm_key):
            st[alarm_key] = False
            return "clear"
    else:
        st[hot_key] = 0
        st[cool_key] = 0
    return None


rx_ev = streak("rx_alarm", "rx_hot", "rx_cool", rx, rx_fire, rx_clear)
tx_ev = streak("tx_alarm", "tx_hot", "tx_cool", tx, tx_fire, tx_clear)

line = f"{iface}  RX {fmt(rx)}  TX {fmt(tx)}"
bits = []
if st.get("rx_alarm"):
    bits.append(f"RX {fmt(rx)} (circuit {rx_mbps:.0f}M)")
if st.get("tx_alarm"):
    bits.append(f"TX {fmt(tx)} (circuit {tx_mbps:.0f}M)")

if rx_ev == "fire" or tx_ev == "fire":
    msgs.append("🔴 WAN saturated\n" + line + "\n" + ", ".join(bits))
elif (rx_ev == "clear" or tx_ev == "clear") and not (
    st.get("rx_alarm") or st.get("tx_alarm")
):
    msgs.append("🟢 WAN normal\n" + line)
elif rx_ev == "clear":
    msgs.append("🟢 WAN RX normal\n" + line)
elif tx_ev == "clear":
    msgs.append("🟢 WAN TX normal\n" + line)

save(st)
if dry:
    print(
        f"STATUS {line} fire RX>={fmt(rx_fire)} TX>={fmt(tx_fire)} "
        f"alarms rx={st.get('rx_alarm')} tx={st.get('tx_alarm')} "
        f"hot {st.get('rx_hot')}/{st.get('tx_hot')}",
        file=sys.stderr,
    )
print(json.dumps(msgs, ensure_ascii=False))
PY
)

n=$(python3 -c 'import json,sys; print(len(json.loads(sys.argv[1] or "[]")))' "$payload")
i=0
while [[ "$i" -lt "$n" ]]; do
  ev=$(python3 -c 'import json,sys; sys.stdout.write(json.loads(sys.argv[1])[int(sys.argv[2])])' "$payload" "$i")
  send "$ev"
  i=$((i + 1))
done
