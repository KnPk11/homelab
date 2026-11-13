# Web-Compromise Watch Deployment

> **Node:** [reverse-proxy](../../deployment.md) (`192.168.50.101`) | **Service Kind:** systemd service (`web-compromise-exec-watch.service`)  
> **Prerequisite:** Host bootstrapped via the [reverse-proxy Master Guide](../../deployment.md).

## 1. Overview & Scope on reverse-proxy

`web-compromise-watch` is a host-level intrusion detection daemon designed to catch reverse shell spawns or unauthorised interactive execution. On `reverse-proxy`, it monitors process execution specifically under the Caddy service account:

> [!NOTE]
> **Why this node has a dedicated runbook:** Unlike general developer hosts (`lab-vm`, `scratch-pc`) that utilise the shared fallback rollout, `reverse-proxy` runs a custom profile locked strictly to Caddy UID `999` with aggressive shell detection (`sh`, `bash`, `python`) and maintains its own in-repo SOPS-encrypted `telegram.env`.

* **Monitored UID:** `999` (`caddy`).
* **Monitored Binaries:** `sh`, `bash`, `dash`, `nc`, `ncat`, `netcat`, `socat`, `python`, `python3`, `perl`.
* **Scan Interval:** Every 10 seconds via `/proc` process table polling.
* **Notification Channel:** Dispatches immediate alert messages to Telegram via Homelab Watch.
* **Shared Reference:** [shared/observability/web-compromise-watch](../../../../shared/observability/web-compromise-watch/deployment.md).

---

## 2. Secrets & Runtime Paths

| Path | Purpose |
| :--- | :--- |
| `nodes/reverse-proxy/services/web-compromise-watch/telegram.env` | In-repo SOPS-encrypted Telegram bot token and chat ID |
| `/srv/homelab-watch/telegram.env` | Runtime secret credentials (mode `600`, not in Git) |
| `/srv/web-compromise-watch/exec-watch.env` | Host-specific execution filter configuration (mode `600`) |
| `/etc/systemd/system/web-compromise-exec-watch.service` | Production systemd unit |

---

## 3. Deployment & Recovery Runbook

1. **Decrypt Secrets:**
   ```bash
   sudo mkdir -p /srv/homelab-watch /srv/web-compromise-watch
   sops -d /opt/homelab-repo/nodes/reverse-proxy/services/web-compromise-watch/telegram.env > /srv/homelab-watch/telegram.env
   sudo chmod 600 /srv/homelab-watch/telegram.env
   ```

2. **Run Host Provisioning Script:**
   Execute the tracked deploy script from the shared observability suite:
   ```bash
   sudo /opt/homelab-repo/shared/observability/web-compromise-watch/deploy.sh
   ```
   *(This generates `/srv/web-compromise-watch/exec-watch.env` for `reverse-proxy`, copies the binary to `/usr/local/sbin/web-compromise-exec-watch`, and enables `web-compromise-exec-watch.service`).*

3. **Verify Service Health:**
   ```bash
   sudo systemctl status web-compromise-exec-watch.service
   ```
