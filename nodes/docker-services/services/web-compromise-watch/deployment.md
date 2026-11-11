# Web-Compromise Watch Deployment

> **Node:** [docker-services](../../deployment.md) (`192.168.50.95`) | **Service Kind:** systemd services (`exec-watch.service`, `docker-events-watch.service`)  
> **Prerequisite:** Host bootstrapped via the [docker-services Master Guide](../../deployment.md).

## 1. Overview & Scope on docker-services

`web-compromise-watch` provides host-level intrusion detection tailored for the container plane (`docker-services`). It operates two complementary monitoring daemons:

> [!NOTE]
> **Why this node has a dedicated runbook:** Unlike general developer hosts (`lab-vm`, `scratch-pc`) that run only basic exec checks, `docker-services` runs a dual-daemon setup (Docker cgroup exec watch + real-time Docker socket port baseline tracking) and maintains its own in-repo SOPS-encrypted `telegram.env`.

1. **Execution Watcher (`exec-watch.service`)**:
   * Scans `/proc` every 10 seconds for processes matching the `docker` cgroup regex.
   * Restricts alerts strictly to interactive reverse-shell utilities: `nc`, `ncat`, `netcat`, `socat` (avoiding false alarms on routine container shell entry).
2. **Docker Events Watcher (`docker-events-watch.service`)**:
   * Monitors `/var/run/docker.sock` for container creation and port bindings.
   * Compares exposed ports against `/var/lib/web-compromise-watch/ports.baseline` to catch unauthorised port publishing.
   * Flags suspicious container flags (e.g. `--privileged`, `--net=host`).
3. **Notification Channel**: Immediate incident alerts dispatched to Telegram via Homelab Watch (`/srv/homelab-watch/telegram.env`).
4. **Shared Reference**: [shared/observability/web-compromise-watch](../../../../shared/observability/web-compromise-watch/deployment.md).

---

## 2. Secrets & Runtime Paths

| Path | Purpose |
| :--- | :--- |
| `nodes/docker-services/services/web-compromise-watch/telegram.env` | In-repo SOPS-encrypted Telegram credentials |
| `/srv/homelab-watch/telegram.env` | Runtime secret credentials (mode `600`, not in Git) |
| `/srv/web-compromise-watch/exec-watch.env` | Execution watcher configuration (mode `600`) |
| `/srv/web-compromise-watch/docker-events.env` | Docker events watcher configuration (mode `600`) |
| `/var/lib/web-compromise-watch/ports.baseline` | Canonical list of allowed host-bound ports |
| `/etc/systemd/system/exec-watch.service` | Execution monitoring systemd unit |
| `/etc/systemd/system/docker-events-watch.service` | Docker socket event monitoring systemd unit |

---

## 3. Deployment & Recovery Runbook

1. **Decrypt Secrets:**
   ```bash
   sudo mkdir -p /srv/homelab-watch /srv/web-compromise-watch
   sops -d /opt/homelab-repo/nodes/docker-services/services/web-compromise-watch/telegram.env > /srv/homelab-watch/telegram.env
   sudo chmod 600 /srv/homelab-watch/telegram.env
   ```

2. **Run Host Provisioning Script:**
   Execute the tracked deploy script from the shared observability suite:
   ```bash
   sudo /opt/homelab-repo/shared/observability/web-compromise-watch/deploy.sh
   ```
   *(This initialises `/srv/web-compromise-watch/*.env`, captures the initial port baseline, and enables both systemd units).*

3. **Verify Service Health:**
   ```bash
   sudo systemctl status exec-watch.service docker-events-watch.service
   ```
