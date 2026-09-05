#!/usr/bin/env bash
# Install weekly-sweep. Reboot/CrowdSec/DSTNAT hosts are fixed; lure lists
# come from ~/.config/ops-local/manifest.json (not git).
set -euo pipefail
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
REPO=$(cd "$SCRIPT_DIR/../../.." && pwd)
SSH_CFG="${SSH_CFG:-$REPO/shared/ssh/config}"
MANIFEST="${MANIFEST:-$HOME/.config/ops-local/manifest.json}"
THIS=$(hostname -s 2>/dev/null || true)

declare -A CHECKS
CHECKS[proxmox-host]=reboot
CHECKS[reverse-proxy]=reboot,crowdsec
CHECKS[docker-services]=reboot
CHECKS[ai-tools]=dstnat,reboot
CHECKS[lab-vm]=reboot
CHECKS[scratch-pc]=reboot
CHECKS[dns]=reboot
CHECKS[k8s]=reboot
CHECKS[nas]=reboot
CHECKS[pbs]=reboot
CHECKS[pulse]=reboot
CHECKS[vpns]=reboot

if [[ -f "$MANIFEST" ]]; then
  while IFS=$'\t' read -r host path; do
    [[ -z "$host" || -z "$path" ]] && continue
    if [[ -n "${CHECKS[$host]:-}" ]]; then
      case ",${CHECKS[$host]}," in
        *,lures,*) ;;
        *) CHECKS[$host]="${CHECKS[$host]},lures" ;;
      esac
    else
      CHECKS[$host]=lures
    fi
  done < <(python3 -c 'import json,sys
data=json.loads(open(sys.argv[1],encoding="utf-8").read())
for t in data.get("tokens") or []:
    host, path = t.get("host") or "", (t.get("path") or "").split(" (")[0]
    if host and path:
        print("%s\t%s" % (host, path))
' "$MANIFEST")
fi

hosts=("${!CHECKS[@]}")
IFS=$'\n' hosts=($(printf '%s\n' "${hosts[@]}" | sort))

echo "Rollout weekly-sweep → ${hosts[*]}"
fail=0

sync_lures() {
  local host="$1"
  local list
  list="$(mktemp)"
  python3 -c 'import json,sys
data=json.loads(open(sys.argv[1],encoding="utf-8").read())
host=sys.argv[2]
for t in data.get("tokens") or []:
    if t.get("host") != host:
        continue
    path=(t.get("path") or "").split(" (")[0]
    if path:
        print(path)
' "$MANIFEST" "$host" >"$list"
  if [[ ! -s "$list" ]]; then
    rm -f "$list"
    return 0
  fi
  if [[ "$host" == "ai-tools" || "$host" == "$THIS" ]]; then
    install -d -m 755 /var/lib/weekly-sweep
    install -m 600 "$list" /var/lib/weekly-sweep/lures.list
  else
    ssh -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 "$host" 'install -d -m 755 /var/lib/weekly-sweep'
    scp -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 -q "$list" "$host:/var/lib/weekly-sweep/lures.list"
    ssh -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 "$host" 'chmod 600 /var/lib/weekly-sweep/lures.list'
  fi
  rm -f "$list"
}

deploy_host() {
  local host="$1" checks="$2"
  echo "----- $host ($checks) -----"
  if [[ ",${checks}," == *",lures,"* ]]; then
    if ! sync_lures "$host"; then
      echo "FAIL $host lure-list"
      return 1
    fi
  fi
  if [[ "$host" == "ai-tools" || "$host" == "$THIS" ]]; then
    CHECKS="$checks" "$SCRIPT_DIR/deploy.sh" --checks "$checks"
    return 0
  fi
  ssh -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 "$host" 'mkdir -p /tmp/weekly-sweep'
  scp -F "$SSH_CFG" -o BatchMode=yes -q \
    "$SCRIPT_DIR/weekly-sweep.sh" \
    "$SCRIPT_DIR/weekly-sweep.service" \
    "$SCRIPT_DIR/weekly-sweep.timer" \
    "$SCRIPT_DIR/dstnat.ports.example" \
    "$SCRIPT_DIR/deploy.sh" \
    "$host:/tmp/weekly-sweep/"
  ssh -F "$SSH_CFG" -o BatchMode=yes -o ConnectTimeout=8 "$host" \
    "chmod +x /tmp/weekly-sweep/deploy.sh /tmp/weekly-sweep/weekly-sweep.sh && /tmp/weekly-sweep/deploy.sh --checks '$checks'"
}

for h in "${hosts[@]}"; do
  if deploy_host "$h" "${CHECKS[$h]}"; then
    echo "OK $h"
  else
    echo "FAIL $h"
    fail=$((fail + 1))
  fi
done
if [[ "$fail" -ne 0 ]]; then
  echo "Finished with $fail failure(s)"
  exit 1
fi
echo "Finished OK"
