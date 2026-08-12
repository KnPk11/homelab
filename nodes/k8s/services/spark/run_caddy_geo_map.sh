#!/usr/bin/env bash
# =============================================================================
# run_caddy_geo_map.sh
# Version: 1.1
# Date: 2026-08-12
#
# Stage or mount Caddy logs and run the Spark geo-map job.
#
# Modes:
#   local (default)  — stage logs to this host, spark-submit --master local[*]
#   k8s              — multi-executor on lab-vm + scratch-pc; requires the same
#                      hostPath on every node (SMB mount of reverse-proxy logs)
#
# k8s scheduling: writes executor-pod-template.yaml (one executor per node,
# workers only — not the control-plane) so both lab-vm and scratch-pc are used.
# Default executor memory is 768m so scratch-pc (~1.8G) can schedule a pod.
#
# Reports: k8s mode writes under /srv/spark/reports (hostPath on every node).
# Spark CSV commits are node-local; map/summary/geocode land on the driver.
# Salvage part-*.csv from workers if needed, or pull from the driver node after.
#
# Firewall (distributed): reverse-proxy CT must allow SMB from Spark nodes
# (main-lan / explicit IPs). See spark setup.md.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB_PY="${SCRIPT_DIR}/caddy_geo_map.py"
[[ -f /opt/spark/caddy_geo_map.py && ! -f "$JOB_PY" ]] && JOB_PY=/opt/spark/caddy_geo_map.py

REVERSE_PROXY_HOST="${REVERSE_PROXY_HOST:-reverse-proxy}"
REVERSE_PROXY_IP="${REVERSE_PROXY_IP:-192.168.50.101}"
# Live JSON + archives (gz). Exclude huge single-file tar snapshots via job filter.
REMOTE_LOG_DIR="${REMOTE_LOG_DIR:-/mnt/logs}"
STAGE_DIR="${STAGE_DIR:-/tmp/caddy-logs-stage}"
OUT_DIR="${OUT_DIR:-/tmp/caddy-geo-out}"
SHARED_LOG_PATH="${SHARED_LOG_PATH:-/mnt/caddy-logs}"
REPORTS_HOST_PATH="${REPORTS_HOST_PATH:-/srv/spark/reports}"
PARTITIONS="${PARTITIONS:-32}"
TOP_N="${TOP_N:-150}"
MODE="${MODE:-local}"   # local | k8s
SPARK_SUBMIT="${SPARK_SUBMIT:-/opt/spark/bin/spark-submit}"
SPARK_MASTER_K8S="${SPARK_MASTER_K8S:-k8s://https://192.168.50.96:6443}"
SPARK_IMAGE="${SPARK_IMAGE:-apache/spark:3.5.1}"
EXECUTOR_INSTANCES="${EXECUTOR_INSTANCES:-2}"
EXECUTOR_CORES="${EXECUTOR_CORES:-1}"
# 768m fits scratch-pc (~1.8G allocatable); raise on larger workers via env.
EXECUTOR_MEMORY="${EXECUTOR_MEMORY:-768m}"
DRIVER_HOST="${DRIVER_HOST:-192.168.50.96}"
# 0 = pack freely; 1 = one executor per worker node (default for multi-node).
SPREAD_EXECUTORS="${SPREAD_EXECUTORS:-1}"
POD_TEMPLATE="${POD_TEMPLATE:-}"

SSH_CFG="${SSH_CFG:-/opt/homelab-repo/shared/ssh/config}"
if [[ ! -f "$SSH_CFG" && -f /opt/dev/homelab_repo/shared/ssh/config ]]; then
  SSH_CFG=/opt/dev/homelab_repo/shared/ssh/config
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

  --mode local|k8s   local[*] on this host (default) or Spark-on-K8s workers
  --skip-stage       Do not rsync (local mode only)
  --skip-geo         No ip-api geocode
  --include-archive  Stage full /mnt/logs tree (current + archive/*.gz)
  --top-n N          Geocode top N IPs (default 150)
  --partitions N     Shuffle partitions (default 32)
  --no-spread        Allow multiple executors on one worker (no anti-affinity)

Env of note:
  SHARED_LOG_PATH      Host path mounted into executors (default /mnt/caddy-logs)
  REPORTS_HOST_PATH    hostPath for job output (default /srv/spark/reports)
  OUT_DIR              Output dir; k8s defaults to REPORTS_HOST_PATH/caddy-geo-<utc>
  EXECUTOR_INSTANCES   default 2 (lab-vm + scratch-pc)
  EXECUTOR_MEMORY      default 768m (scratch-pc friendly)
  SPREAD_EXECUTORS     1=one pod per node (default), 0=pack freely
  POD_TEMPLATE         Override path to executor pod template YAML
EOF
}

SKIP_STAGE=0
SKIP_GEO=0
INCLUDE_ARCHIVE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --skip-stage) SKIP_STAGE=1; shift ;;
    --skip-geo) SKIP_GEO=1; shift ;;
    --include-archive) INCLUDE_ARCHIVE=1; shift ;;
    --top-n) TOP_N="$2"; shift 2 ;;
    --partitions) PARTITIONS="$2"; shift 2 ;;
    --no-spread) SPREAD_EXECUTORS=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$JOB_PY" ]]; then
  echo "Job script not found: $JOB_PY" >&2
  exit 1
fi

GEO_FLAG=()
[[ "$SKIP_GEO" -eq 1 ]] && GEO_FLAG=(--skip-geo)

stage_local() {
  local remote_src="$REMOTE_LOG_DIR/current/caddy"
  if [[ "$INCLUDE_ARCHIVE" -eq 1 ]]; then
    remote_src="$REMOTE_LOG_DIR"
  fi
  echo "[stage] rsync ${REVERSE_PROXY_HOST}:${remote_src}/ → ${STAGE_DIR}/"
  mkdir -p "$STAGE_DIR"
  local rsync_e=(rsync -az --no-owner --no-group)
  if [[ -f "$SSH_CFG" ]]; then
    rsync_e+=(-e "ssh -F ${SSH_CFG} -o BatchMode=yes -o ConnectTimeout=15")
  fi
  # Prefer JSON + gzip archives; skip giant tar snapshots
  "${rsync_e[@]}" \
    --include='*/' \
    --include='*.log' \
    --include='*.json' \
    --include='*.jsonl' \
    --include='*.gz' \
    --exclude='*.tar.gz' \
    --exclude='*.tgz' \
    --exclude='*' \
    "${REVERSE_PROXY_HOST}:${remote_src}/" "${STAGE_DIR}/" || {
      echo "[stage] direct rsync failed (often: reverse-proxy SSH not allowed from this host)." >&2
      echo "        Stage via ai-tools/jump host, or mount SMB ${SHARED_LOG_PATH}." >&2
      return 1
    }
  echo "[stage] $(find "$STAGE_DIR" -type f | wc -l) files, $(du -sh "$STAGE_DIR" | awk '{print $1}')"
}

# Write executor pod template: workers only + optional one-pod-per-node anti-affinity.
write_executor_pod_template() {
  local dest="$1"
  local spread="${2:-1}"
  mkdir -p "$(dirname "$dest")"
  if [[ "$spread" -eq 1 ]]; then
    cat >"$dest" <<'EOF'
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: spark-role
                operator: In
                values:
                  - executor
          topologyKey: kubernetes.io/hostname
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: DoesNotExist
              - key: node-role.kubernetes.io/master
                operator: DoesNotExist
EOF
  else
    cat >"$dest" <<'EOF'
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: DoesNotExist
              - key: node-role.kubernetes.io/master
                operator: DoesNotExist
EOF
  fi
  echo "[k8s] executor pod template → ${dest} (spread=${spread})"
}

run_local() {
  local input="$STAGE_DIR"
  if [[ "$SKIP_STAGE" -eq 0 ]]; then
    stage_local
  else
    echo "[stage] skipped — input ${input}"
  fi
  mkdir -p "$OUT_DIR"
  echo "[spark] local[*] partitions=${PARTITIONS}"
  exec "$SPARK_SUBMIT" \
    --master "local[*]" \
    --name caddy-geo-map \
    --conf spark.driver.memory=3g \
    --conf spark.sql.shuffle.partitions="$PARTITIONS" \
    "$JOB_PY" \
    --input "$input" \
    --output "$OUT_DIR" \
    --partitions "$PARTITIONS" \
    --top-n "$TOP_N" \
    "${GEO_FLAG[@]}"
}

run_k8s() {
  # Expect SHARED_LOG_PATH present on driver + every worker (SMB/NFS)
  if [[ ! -d "$SHARED_LOG_PATH" ]]; then
    echo "[k8s] missing ${SHARED_LOG_PATH} on this host." >&2
    echo "      Mount reverse-proxy logs SMB on k8s, lab-vm, scratch-pc first:" >&2
    echo "        //${REVERSE_PROXY_IP}/logs  →  ${SHARED_LOG_PATH}" >&2
    echo "      And allow SMB from homelab-lan on reverse-proxy (Proxmox file-svc)." >&2
    exit 1
  fi
  if [[ ! -d "$SHARED_LOG_PATH/current/caddy" && ! -d "$SHARED_LOG_PATH/caddy" ]]; then
    echo "[k8s] ${SHARED_LOG_PATH} does not look like the logs share (no current/caddy)." >&2
    exit 1
  fi

  # Client-mode driver runs on the host FS; executors use hostPath.
  # Use the SAME absolute path on every node (default /mnt/caddy-logs) so
  # driver + executors all open identical paths.
  local input_path="${SHARED_LOG_PATH}/current/caddy"
  if [[ "$INCLUDE_ARCHIVE" -eq 1 ]]; then
    input_path="$SHARED_LOG_PATH"
  fi

  # Prefer reports hostPath so executor CSV tasks can see the same tree.
  # If caller left the local-mode default, stamp a UTC run dir under reports.
  if [[ "$OUT_DIR" == "/tmp/caddy-geo-out" ]]; then
    OUT_DIR="${REPORTS_HOST_PATH}/caddy-geo-$(date -u +%Y%m%dT%H%M%SZ)"
  fi
  mkdir -p "$OUT_DIR" /srv/spark/events "$REPORTS_HOST_PATH"
  chmod 1777 "$REPORTS_HOST_PATH" 2>/dev/null || true

  local template="${POD_TEMPLATE}"
  if [[ -z "$template" ]]; then
    if [[ -d /opt/spark && -w /opt/spark ]]; then
      template=/opt/spark/executor-pod-template.yaml
    else
      template="${SCRIPT_DIR}/executor-pod-template.yaml"
    fi
    write_executor_pod_template "$template" "$SPREAD_EXECUTORS"
  elif [[ ! -f "$template" ]]; then
    echo "[k8s] POD_TEMPLATE not found: $template" >&2
    exit 1
  else
    echo "[k8s] using POD_TEMPLATE=${template}"
  fi

  TOKEN=$(kubectl create token spark -n spark --duration=24h)

  echo "[spark] k8s executors=${EXECUTOR_INSTANCES} mem=${EXECUTOR_MEMORY} input=${input_path}"
  echo "[spark] out=${OUT_DIR} (reports hostPath ${REPORTS_HOST_PATH})"
  echo "OUT=$OUT_DIR" >"${REPORTS_HOST_PATH}/spark-geo-k8s.last-out" 2>/dev/null || true

  # shellcheck disable=SC2086
  exec "$SPARK_SUBMIT" \
    --master "$SPARK_MASTER_K8S" \
    --deploy-mode client \
    --name caddy-geo-map \
    --conf spark.eventLog.enabled=true \
    --conf spark.eventLog.dir=file:/srv/spark/events \
    --conf spark.kubernetes.container.image="$SPARK_IMAGE" \
    --conf spark.kubernetes.namespace=spark \
    --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
    --conf spark.kubernetes.authenticate.oauthToken="$TOKEN" \
    --conf spark.kubernetes.trust.certificates=true \
    --conf spark.kubernetes.executor.podTemplateFile="$template" \
    --conf spark.executor.instances="$EXECUTOR_INSTANCES" \
    --conf spark.executor.cores="$EXECUTOR_CORES" \
    --conf spark.executor.memory="$EXECUTOR_MEMORY" \
    --conf spark.driver.host="$DRIVER_HOST" \
    --conf spark.driver.port=7078 \
    --conf spark.blockManager.port=7079 \
    --conf spark.driver.memory=2g \
    --conf spark.sql.shuffle.partitions="$PARTITIONS" \
    --conf spark.kubernetes.executor.volumes.hostPath.clogsmount.mount.path="$SHARED_LOG_PATH" \
    --conf spark.kubernetes.executor.volumes.hostPath.clogsmount.options.path="$SHARED_LOG_PATH" \
    --conf spark.kubernetes.executor.volumes.hostPath.clogsmount.mount.readOnly=true \
    --conf spark.kubernetes.executor.volumes.hostPath.sparkreports.mount.path="$REPORTS_HOST_PATH" \
    --conf spark.kubernetes.executor.volumes.hostPath.sparkreports.options.path="$REPORTS_HOST_PATH" \
    --conf spark.kubernetes.executor.volumes.hostPath.sparkreports.mount.readOnly=false \
    "$JOB_PY" \
    --input "$input_path" \
    --output "$OUT_DIR" \
    --partitions "$PARTITIONS" \
    --top-n "$TOP_N" \
    "${GEO_FLAG[@]}"
}

case "$MODE" in
  local) run_local ;;
  k8s) run_k8s ;;
  *) echo "Unknown mode: $MODE" >&2; exit 1 ;;
esac
