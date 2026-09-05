#!/usr/bin/env bash
# Install weekly-sweep on this host. CHECKS from --checks or auto-detect.
set -euo pipefail
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CHECKS="${CHECKS:-}"
THIS_HOST=$(hostname -s 2>/dev/null || hostname)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --checks) CHECKS="${2:-}"; shift 2 ;;
    *) echo "usage: deploy.sh --checks reboot,crowdsec,dstnat,lures" >&2; exit 2 ;;
  esac
done

if [[ -z "$CHECKS" ]]; then
  auto=()
  [[ -d /etc/pve ]] && auto+=(reboot)
  case "$THIS_HOST" in
    reverse-proxy|docker-services|lab-vm|scratch-pc|dns|k8s|nas|pbs|pulse|vpns|ai-tools)
      auto+=(reboot) ;;
  esac
  command -v cscli >/dev/null 2>&1 && auto+=(crowdsec)
  [[ -f /root/.ssh/id_ed25519_mt_backup ]] && auto+=(dstnat)
  [[ -s /var/lib/weekly-sweep/lures.list ]] && auto+=(lures)
  CHECKS=$(IFS=,; echo "${auto[*]}")
fi
if [[ -z "$CHECKS" ]]; then
  echo "deploy.sh: nothing to check on ${THIS_HOST}" >&2
  exit 1
fi

install -d -m 755 /var/lib/weekly-sweep
install -m 755 "$SCRIPT_DIR/weekly-sweep.sh" /usr/local/sbin/weekly-sweep
install -m 644 "$SCRIPT_DIR/weekly-sweep.service" /etc/systemd/system/weekly-sweep.service
install -m 644 "$SCRIPT_DIR/weekly-sweep.timer" /etc/systemd/system/weekly-sweep.timer

install -d -m 700 /srv/homelab-watch || true
if [[ ! -s /etc/ssh/telegram.env && -s /srv/homelab-watch/telegram.env ]]; then
  install -m 600 /srv/homelab-watch/telegram.env /etc/ssh/telegram.env || true
fi
TG=/etc/ssh/telegram.env
[[ -s /etc/ssh/telegram.env ]] || TG=/srv/homelab-watch/telegram.env

if [[ ",${CHECKS}," == *",dstnat,"* ]]; then
  if [[ ! -f /var/lib/weekly-sweep/dstnat.ports ]]; then
    install -m 644 "$SCRIPT_DIR/dstnat.ports.example" /var/lib/weekly-sweep/dstnat.ports
  fi
fi

cat > /etc/default/weekly-sweep <<EOF
CHECKS=${CHECKS}
TELEGRAM_ENV=${TG}
DSTNAT_PORTS=/var/lib/weekly-sweep/dstnat.ports
LURES_LIST=/var/lib/weekly-sweep/lures.list
WG_PORT=51821
CROWDSEC_BOUNCERS=mikrotik-bouncer,firewall-bouncer
EOF
chmod 644 /etc/default/weekly-sweep

systemctl daemon-reload
systemctl enable --now weekly-sweep.timer
echo "weekly-sweep installed on ${THIS_HOST} checks=${CHECKS}"
