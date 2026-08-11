# Pulse Deployment Notes

> [!NOTE]
> #Pulse #Monitoring #Proxmox #LXC


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

**Preferred:** Pulse UI → **Settings → Infrastructure → Install on a host** (type **pve**), then run the generated command **as root on the Proxmox host** (not inside the CT). That creates a managed API token and writes `nodes.enc` in the CT.

Example shape only (regenerate from UI; tokens are one-shot):

```bash
curl -fsSL 'http://<PULSE_IP>:<PORT>/api/setup-script?type=pve&host=https%3A%2F%2F<PVE_IP>%3A8006&pulse_url=http%3A%2F%2F<PULSE_IP>%3A<PORT>&backup_perms=true' \
  | env PULSE_SETUP_TOKEN='<from-ui>' bash
```

**Firewall (required):** PVE host must allow this CT to reach **TCP 8006**. Repo source of truth: `nodes/proxmox-host/scripts/firewall.sh` (alias `pulse-monitor` + host rule). Guest firewall: SSH (`ssh-adm`), ping, **`proxy-back` only** for the UI (Caddy; no direct LAN/VPN to the port).

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

## 5. Security / scope

- **UI only via Caddy** (`access_policy_lan`). Guest FW does **not** open the port to main-lan/vpn; only `GROUP proxy-back`.
- Auth required for stats (`PULSE_AUTH_*` after bootstrap). No guest/anonymous metrics mode.
- Embedding off (`allowEmbedding: false`) — open Pulse in its own tab, not Dashy iframe.
- CT **protection** enabled (prevents accidental delete/stop from UI without unlock).
- Prefer static/DHCP reservation so `pulse-monitor` firewall alias stays valid.

## 6. Related

- Firewall: `nodes/proxmox-host/scripts/firewall.sh`, `firewall.env.example` (`PULSE_MONITOR_IP`)
- Private notes: `docs_private/services/public-homepage-and-host-monitoring.md`
- Upstream: [Install](https://github.com/rcourtman/Pulse/blob/main/docs/INSTALL.md), [Configuration](https://github.com/rcourtman/Pulse/blob/main/docs/CONFIGURATION.md)
