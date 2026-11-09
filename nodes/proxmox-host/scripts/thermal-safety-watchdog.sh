#!/usr/bin/env bash
# =============================================================================
# Thermal Safety Watchdog & Emergency Graceful Shutdown
# Version: 1.1
# Location: nodes/proxmox-host/scripts/thermal-safety-watchdog.sh
#
# Purpose:
#   Continuously monitors Intel CPU package temperature via sysfs.
#   If a sustained thermal anomaly is detected (e.g. blower fan seizure),
#   this script alerts the administrator and gracefully powers down Proxmox
#   guests and the host before the hardware THERMTRIP# threshold (~100°C) is
#   reached, preventing database corruption and dirty filesystem states.
#
# Deployment:
#   Runs as a root cron job (every minute) or a systemd timer (every 30s).
#   To test without shutting down:
#     ./thermal-safety-watchdog.sh --dry-run
#   To exercise the full emergency path (incl. a real Telegram alert) on a
#   cool machine, lower the thresholds and run it REQUIRED_CONSECUTIVE_SAMPLES
#   times:
#     sudo WARN_TEMP=20 CRIT_TEMP=30 ./thermal-safety-watchdog.sh --dry-run
#
# Telegram:
#   Reuses the host-local env file deployed by the SSH doorbell
#   (shared/observability/ssh-doorbell/deploy.sh) — /etc/ssh/telegram.env,
#   falling back to /srv/homelab-watch/telegram.env. Expects BOT_TOKEN and
#   CHAT_ID (TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID also accepted).
# =============================================================================

set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# -----------------------------------------------------------------------------
# Configuration (thresholds may be overridden via environment for testing)
# -----------------------------------------------------------------------------
# Thermal thresholds in degrees Celsius
WARN_TEMP="${WARN_TEMP:-80}"        # Threshold to log warning
CRIT_TEMP="${CRIT_TEMP:-92}"        # Threshold to initiate emergency shutdown sequence

# Persistence requirements
# Number of consecutive critical readings before triggering shutdown
# (e.g. 4 checks * 30 seconds = 2 minutes sustained temperature)
REQUIRED_CONSECUTIVE_SAMPLES="${REQUIRED_CONSECUTIVE_SAMPLES:-4}"

# State file tracking consecutive critical checks in memory (lost on reboot)
STATE_FILE="/run/thermal-safety-watchdog.state"
# Marker so a broken sensor alerts once rather than every run
SENSOR_FAIL_MARKER="/run/thermal-safety-watchdog.sensor-fail"

# Logging & Alerting
LOG_TAG="thermal-watchdog"
TELEGRAM_ENV_CANDIDATES=("/etc/ssh/telegram.env" "/srv/homelab-watch/telegram.env")

# Dry run flag
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-d" ]]; then
    DRY_RUN=1
    echo "[i] Running in DRY-RUN mode. No shutdown actions will be executed."
fi

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*"
    logger -t "$LOG_TAG" -p daemon.info "$*"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" >&2
    logger -t "$LOG_TAG" -p daemon.warning "$*"
}

log_crit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CRITICAL: $*" >&2
    logger -t "$LOG_TAG" -p daemon.crit "$*"
}

send_telegram_alert() {
    local message="$1"
    local env_file="" f token chat prefix=""

    for f in "${TELEGRAM_ENV_CANDIDATES[@]}"; do
        if [[ -r "$f" ]]; then
            env_file="$f"
            break
        fi
    done
    if [[ -z "$env_file" ]]; then
        log_warn "No Telegram env file found (${TELEGRAM_ENV_CANDIDATES[*]}); alert not sent."
        return 0
    fi

    # Source in a subshell so the env file cannot clobber script variables
    # shellcheck disable=SC1090
    token=$( . "$env_file" >/dev/null 2>&1; echo "${BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}" ) || token=""
    # shellcheck disable=SC1090
    chat=$( . "$env_file" >/dev/null 2>&1; echo "${CHAT_ID:-${TELEGRAM_CHAT_ID:-}}" ) || chat=""
    if [[ -z "$token" || -z "$chat" ]]; then
        log_warn "Telegram credentials missing in ${env_file}; alert not sent."
        return 0
    fi

    (( DRY_RUN == 1 )) && prefix="[DRY-RUN] "

    # Hard timeout so a network/DNS hang can never delay the emergency shutdown.
    # Plain text (no parse_mode) so hostnames/underscores cannot break delivery.
    curl -sS --connect-timeout 5 --max-time 10 \
        -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        --data-urlencode "chat_id=${chat}" \
        --data-urlencode "text=🔥 ${prefix}[Thermal Alert] $(hostname): ${message}" \
        >/dev/null 2>&1 || log_warn "Telegram alert delivery failed."
}

read_zone_temp_c() {
    # Prints whole degrees C from a sysfs zone temp file; fails on bad data
    local raw
    raw=$(cat "$1" 2>/dev/null) || return 1
    [[ "$raw" =~ ^-?[0-9]+$ ]] || return 1
    echo "$((raw / 1000))"
}

get_cpu_package_temp() {
    # 1. Native Linux sysfs thermal zones (zero external dependencies)
    local zone type
    for zone in /sys/class/thermal/thermal_zone*; do
        if [[ -f "${zone}/type" && -f "${zone}/temp" ]]; then
            type=$(cat "${zone}/type" 2>/dev/null || true)
            if [[ "$type" == "x86_pkg_temp" || "$type" == "coretemp" || "$type" == "cpu_thermal" ]]; then
                read_zone_temp_c "${zone}/temp" && return 0
            fi
        fi
    done

    # 2. Fallback to lm-sensors coretemp if sysfs names differ
    if command -v sensors &>/dev/null; then
        local sensors_temp
        sensors_temp=$(sensors coretemp-isa-0000 2>/dev/null | awk '/Package id 0:/ {print $4}' | tr -d '+°C' | cut -d'.' -f1 || true)
        if [[ -n "$sensors_temp" && "$sensors_temp" =~ ^[0-9]+$ ]]; then
            echo "$sensors_temp"
            return 0
        fi
    fi

    # No blind thermal_zone0 fallback: on this hardware it is the PCH sensor,
    # which reads far cooler than the CPU and would mask a real overheat.
    return 1
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
CURRENT_TEMP=$(get_cpu_package_temp) || CURRENT_TEMP=""

if [[ -z "$CURRENT_TEMP" || ! "$CURRENT_TEMP" =~ ^[0-9]+$ ]]; then
    log_crit "Failed to obtain a valid CPU package temperature. Thermal protection is NOT active."
    if [[ ! -f "$SENSOR_FAIL_MARKER" ]]; then
        send_telegram_alert "Thermal watchdog cannot read the CPU package temperature — thermal protection is NOT active. Check sysfs/lm-sensors."
        touch "$SENSOR_FAIL_MARKER"
    fi
    exit 1
fi

if [[ -f "$SENSOR_FAIL_MARKER" ]]; then
    rm -f "$SENSOR_FAIL_MARKER"
    log_info "CPU temperature sensor readable again."
    send_telegram_alert "Thermal watchdog can read the CPU temperature again (${CURRENT_TEMP}°C). Protection restored."
fi

log_info "CPU Package Temperature: ${CURRENT_TEMP}°C (Warn: ${WARN_TEMP}°C, Crit: ${CRIT_TEMP}°C)"

# Below critical: any reading under CRIT_TEMP breaks the consecutive streak
if (( CURRENT_TEMP < CRIT_TEMP )); then
    if [[ -f "$STATE_FILE" ]]; then
        log_info "Temperature dropped below critical. Resetting consecutive critical counter."
        rm -f "$STATE_FILE"
    fi
    if (( CURRENT_TEMP >= WARN_TEMP )); then
        log_warn "Elevated CPU temperature detected: ${CURRENT_TEMP}°C (Threshold: ${WARN_TEMP}°C)."
    fi
    exit 0
fi

# Temperature is at or above CRIT_TEMP
log_crit "CPU temperature is ${CURRENT_TEMP}°C! (Critical Threshold: ${CRIT_TEMP}°C)"

# Read current consecutive count from state file (treat corrupt content as 0)
PREVIOUS_COUNT=0
if [[ -f "$STATE_FILE" ]]; then
    PREVIOUS_COUNT=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    [[ "$PREVIOUS_COUNT" =~ ^[0-9]+$ ]] || PREVIOUS_COUNT=0
fi
CONSECUTIVE_COUNT=$((PREVIOUS_COUNT + 1))

echo "$CONSECUTIVE_COUNT" > "$STATE_FILE"
log_crit "Critical temperature persistence: ${CONSECUTIVE_COUNT}/${REQUIRED_CONSECUTIVE_SAMPLES} consecutive checks."

# If we haven't reached the persistence threshold yet, exit and wait for next check
if (( CONSECUTIVE_COUNT < REQUIRED_CONSECUTIVE_SAMPLES )); then
    log_warn "Sustained high temperature window in progress. Awaiting next sample before emergency action."
    exit 0
fi

# -----------------------------------------------------------------------------
# Emergency Action Triggered
# -----------------------------------------------------------------------------
EMERGENCY_MSG="CPU temperature has remained at or above ${CRIT_TEMP}°C for ${CONSECUTIVE_COUNT} consecutive checks (${CURRENT_TEMP}°C). Suspected cooling fan failure. Initiating graceful emergency shutdown."

log_crit "$EMERGENCY_MSG"
send_telegram_alert "$EMERGENCY_MSG"

if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] Would have executed: pvesh create /nodes/\$(hostname)/stopall"
    echo "[DRY-RUN] Would have executed: sync"
    echo "[DRY-RUN] Would have executed: shutdown -h now \"$EMERGENCY_MSG\""
    # Reset so repeated dry-run tests start a fresh streak
    rm -f "$STATE_FILE"
    exit 0
fi

# 1. Gracefully stop all running Proxmox VMs and containers
if command -v pvesh &>/dev/null; then
    log_info "Sending graceful stop signal to all Proxmox guests..."
    pvesh create "/nodes/$(hostname)/stopall" >/dev/null 2>&1 || true
    # Allow 15 seconds for critical database flushes
    sleep 15
fi

# 2. Flush disk buffers
sync

# 3. Order immediate graceful poweroff
shutdown -h now "$EMERGENCY_MSG"
