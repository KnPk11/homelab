#!/usr/bin/env bash
# Read-only SMB of /mnt/logs (plaintext auth/) for Windows backup. Same loguser as reverse-proxy.
set -euo pipefail
REPO="${REPO:-/opt/homelab-repo}"
SRC="$REPO/nodes/syslog/services/smb"

if [[ ! -d /mnt/logs ]]; then
  echo "Error: /mnt/logs missing" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if ! dpkg -s samba >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq samba
fi

if ! id loguser >/dev/null 2>&1; then
  useradd --system --uid 1001 --home-dir /home/loguser --create-home \
    --shell /usr/sbin/nologin loguser
fi
install -d -m 755 /mnt/logs /mnt/logs/auth
chown root:root /mnt/logs /mnt/logs/auth
chmod 755 /mnt/logs /mnt/logs/auth

install -m 644 "$SRC/smb.conf" /etc/samba/smb.conf
systemctl enable --now smbd.service
systemctl disable --now nmbd.service 2>/dev/null || true
systemctl restart smbd.service
systemctl is-active smbd.service

if ! pdbedit -L 2>/dev/null | grep -q '^loguser:'; then
  echo "Samba user loguser is not in passdb yet."
  echo "On this host, set the same password as //reverse-proxy/logs:"
  echo "  sudo smbpasswd -a loguser"
fi

echo "SMB share //$(hostname -s)/logs  user=loguser  read-only /mnt/logs"
