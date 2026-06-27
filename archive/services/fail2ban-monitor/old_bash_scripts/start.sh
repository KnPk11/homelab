#!/bin/sh
# Start Caddy in background
caddy run --config /etc/caddy/Caddyfile &

# Start Python server in foreground
python3 /usr/local/bin/fail2ban_bans.py
