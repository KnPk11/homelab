# Thermal Safety Watchdog Deployment

> **Location:** `nodes/proxmox-host/services/thermal-watchdog/deployment.md`  
> **Node:** `proxmox-host` (`pve1`, `192.168.50.100`)

## 1. Overview & Architecture

The thermal safety watchdog continuously monitors the CPU package temperature via Linux sysfs. If a sustained thermal anomaly is detected (e.g. blower fan failure or clogged heatsink on a compact chassis), it alerts the administrator via Telegram and initiates a graceful shutdown of Proxmox guests and the host before the hardware THERMTRIP# threshold (~100°C) is reached.

* **Check Interval:** Every 30 seconds via systemd timer (`thermal-watchdog.timer`).
* **Warning Threshold:** ≥ 80°C (logged to journald).
* **Critical Threshold:** ≥ 90°C sustained for 4 consecutive samples (~2 minutes).
* **Emergency Action:** Sends Telegram alert → signals Proxmox guests to stop (`pvesh create /nodes/$(hostname)/stopall`) → flushes disk buffers (`sync`) → powers off (`shutdown -h now`).

---

## 2. Secrets & Dependencies

* **Script:** [`../../scripts/thermal-safety-watchdog.sh`](../scripts/thermal-safety-watchdog.sh)
* **Telegram Secrets:** Reuses the host-local `/etc/ssh/telegram.env` provisioned by the [SSH doorbell](../../../shared/observability/ssh-doorbell/deployment.md) (falling back to `/srv/homelab-watch/telegram.env`). Expects `BOT_TOKEN` and `CHAT_ID`.

---

## 3. Deployment & Enablement

1. Link the script to PATH:
   ```bash
   REPO=/opt/homelab-repo/nodes/proxmox-host
   sudo chmod +x "$REPO/scripts/thermal-safety-watchdog.sh"
   sudo ln -sfn "$REPO/scripts/thermal-safety-watchdog.sh" /usr/local/bin/thermal-safety-watchdog.sh
   ```

2. Install and enable the systemd units:
   ```bash
   sudo cp "$REPO/services/thermal-watchdog/thermal-watchdog.service" /etc/systemd/system/
   sudo cp "$REPO/services/thermal-watchdog/thermal-watchdog.timer" /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now thermal-watchdog.timer
   ```

*(Alternative: if running without systemd timers, add a root cron job: `* * * * * /usr/local/bin/thermal-safety-watchdog.sh >/dev/null 2>&1`)*

---

## 4. Testing & Verification

1. **Verify Timer Active:**
   ```bash
   systemctl list-timers thermal-watchdog.timer
   ```

2. **Simulate Overheat in Dry-Run Mode (Exercises Telegram without shutdown):**
   Run the following loop 4 times to verify the persistence logic and Telegram dispatch:
   ```bash
   for i in 1 2 3 4; do
     sudo WARN_TEMP=20 CRIT_TEMP=30 thermal-safety-watchdog.sh --dry-run
     sleep 1
   done
   ```

3. **Check Live Logs:**
   ```bash
   journalctl -t thermal-watchdog -f
   ```
