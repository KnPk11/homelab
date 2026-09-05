# Pulse Deployment Notes

> [!NOTE]
> #Pulse #Monitoring #Proxmox #LXC #Telegram #Apprise


## 1. Description

Pulse is a private multi-host monitoring dashboard for Proxmox and related infrastructure — host/CT/VM health, metrics, and alerts in one UI.

## 2. Install (on Proxmox host, creates the LXC)

Upstream installer runs **as root on the Proxmox host** and builds a Debian LXC with a **systemd** Pulse server.

```bash
# Prefer latest stable tag at install time (example shape: v6.2.1)
export PULSE_VERSION=[LATEST-PULSE-VERSION]
# Optional auto-resolve (needs curl + jq on the Proxmox host):
# export PULSE_VERSION="$(curl -fsSL https://api.github.com/repos/rcourtman/Pulse/releases/latest | jq -r .tag_name)"

curl -fsSLO "https://github.com/rcourtman/Pulse/releases/download/${PULSE_VERSION}/install.sh"
curl -fsSLO "https://github.com/rcourtman/Pulse/releases/download/${PULSE_VERSION}/install.sh.sshsig"
ssh-keygen -Y verify \
  -f <(printf '%s\n' 'pulse-installer namespaces="pulse-install" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMZd/DaH+BldzOkq1A8KVTcFk73nAyrE8aJOyf7i00jm pulse-installer') \
  -I pulse-installer \
  -n pulse-install \
  -s install.sh.sshsig < install.sh
bash install.sh --version "${PULSE_VERSION}" --disable-auto-updates
```

First-time UI setup: open the printed URL, paste the **bootstrap token** from the installer (or):

```bash
pct exec <CT_ID> -- env PULSE_DATA_DIR=/etc/pulse /opt/pulse/bin/pulse bootstrap-token
```

## 3. Connect Proxmox (preferred)

Manual “Add node” is easy to get wrong (self-signed TLS; Close without Save).

**Preferred:** Pulse UI → **Settings → Infrastructure → Install on a host** (type **pve**). Run the generated command **as root on the Proxmox host**, not inside the CT. That writes `nodes.enc`. Tokens are one-shot — regenerate from the UI.

**Firewall:** PVE must allow this CT to **TCP 8006** (`nodes/proxmox-host/scripts/firewall.sh`, alias `pulse-monitor`). Guest FW: `ssh-adm`, ping, **`proxy-back`** only (Caddy). No direct LAN/VPN to the Pulse port.

### Unified agent on the Proxmox host

API token ≠ host agent. Temperature / SMART needs **`pulse-agent`** on the hypervisor. Generate the installer in **Settings → Infrastructure** and run it **as root on pve1**, not in the Pulse CT.

Caddy **308s HTTP → HTTPS**. If the snippet uses `http://pulse.example.com`, the agent never reports (`use the final Pulse URL explicitly`). After install, set `--url https://pulse.example.com` and `PULSE_URL` in `/var/lib/pulse-agent/connection.env`, then restart `pulse-agent`. Keep `--insecure` if the UI set it. Leave **command execution off**.

Uninstall: `bash /var/lib/pulse-agent/install.sh --uninstall`.

## 4. Day-2 ops

```bash
pct enter <CT_ID>                 # shell
systemctl status pulse
journalctl -u pulse -f
/opt/pulse/bin/pulse version
apt-get install -y rsync          # Required for scrape_configs_and_secrets.sh
```

### Update server (in-CT)

This lab keeps auto-updates **disabled** (`--disable-auto-updates`). When the UI reports a new version, pin the **latest** tag again and upgrade:

```bash
export PULSE_VERSION=[LATEST-PULSE-VERSION]   # from GitHub Releases /latest
# Optional: export PULSE_VERSION="$(curl -fsSL https://api.github.com/repos/rcourtman/Pulse/releases/latest | jq -r .tag_name)"

# Preferred when present (created by the installer):
/bin/update --version "${PULSE_VERSION}"
```

Data/config (inside CT): `/etc/pulse/` (`nodes.enc`, `system.json`, `.env`, metrics DB).

## 5. Notifications (Telegram)

Threshold alerts (host/guest **down**) via Apprise. Not Pulse **AI Patrol**.

The binary does not ship Telegram. Install the CLI, then **Alerts → Notifications** (stored in `/etc/pulse/apprise.enc`):

```bash
apt-get install -y apprise
```

```text
tgram://[BOT-TOKEN]/[CHAT-ID]
```

Use the **full** BotFather token (digits, colon, then `AAF…`). A tail-only token makes `apprise` exit 1. Do not commit the token. **Send test** in the UI; the CT needs WAN to `api.telegram.org`.

Page **offline / dead PBS**, not CPU or Docker image-update noise. Mute agents on machines that sleep. Grouping is ~60s — a blip that clears inside that window may never notify.

**Patrol:** leave it in the Pulse UI (or turn auto-on-alert patrol off). Do not send Patrol to Telegram. The configured model `stepfun-ai/step-3.7-flash` returned **410 Gone** (EOL 2026-08-28); pick a live model if you still want UI analysis.

## 6. Security / scope

- **UI only via Caddy** (`access_policy_lan`). Guest FW does **not** open the port to main-lan/vpn; only `GROUP proxy-back`.
- Auth required for stats (`PULSE_AUTH_*` after bootstrap). No guest/anonymous metrics mode.
- Embedding off (`allowEmbedding: false`) — open Pulse in its own tab, not Dashy iframe.
- CT **protection** enabled (prevents accidental delete/stop from UI without unlock).
- Prefer static/DHCP reservation so `pulse-monitor` firewall alias stays valid.

## 7. Related

- Firewall: `nodes/proxmox-host/scripts/firewall.sh`, `firewall.env.example` (`PULSE_MONITOR_IP`)
- Private notes: `docs_private/services/public-homepage-and-host-monitoring.md`
- Upstream: [Install](https://github.com/rcourtman/Pulse/blob/main/docs/INSTALL.md), [Configuration](https://github.com/rcourtman/Pulse/blob/main/docs/CONFIGURATION.md)
