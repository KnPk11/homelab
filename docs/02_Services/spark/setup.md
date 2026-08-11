# Apache Spark on Kubernetes Setup & Administration Guide

A clean, minimal reference guide for deploying, operating, and running distributed PySpark jobs on a `k3s` Kubernetes cluster in your homelab environment.

---

## 1. Overview & Architecture

* **Engine**: Apache Spark `3.5.1` (PySpark with OpenJDK 21)
* **Cluster Engine**: `k3s` (Rancher Lightweight Kubernetes `v1.30.2+k3s1`)
* **Deployment Pattern**: Spark-on-K8s (Client Mode / Dispatcher Pattern)
* **Control Plane Node**: `k8s` (`192.168.50.96`, LXC CT 110) — Tainted with `NoSchedule` (runs `spark-submit` dispatcher CLI & driver)
* **Worker Compute Nodes**:
  * `lab-vm` (`192.168.50.91`, VM 103)
  * `scratch-pc` (`192.168.50.85`, Bare-Metal)

### Network & Port Allocations

| Port | Protocol | Description | Notes |
| :--- | :--- | :--- | :--- |
| **`6443`** | TCP | K8s API Server | Spark Driver → K8s API pod creation |
| **`4040`** | TCP | Spark Web UI | Driver job UI (ephemeral, active during job runs) |
| **`18080`** | TCP | Spark History Server | Persistent web daemon for completed & active jobs |
| **`7077`** | TCP | Spark Master (Legacy) | Not needed in Spark-on-K8s mode |
| **`8472`** | UDP | Flannel VXLAN | Inter-executor communication overlay |

---

## 2. Namespace & RBAC Setup

On the `k8s` control-plane host (`192.168.50.96`):

```bash
# Create spark namespace
kubectl create ns spark --dry-run=client -o yaml | kubectl apply -f -

# Create ServiceAccount for Spark driver
kubectl create serviceaccount spark -n spark --dry-run=client -o yaml | kubectl apply -f -

# Bind edit ClusterRole to spark ServiceAccount inside spark namespace
kubectl create rolebinding spark-role \
  --clusterrole=edit \
  --serviceaccount=spark:spark \
  -n spark \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 3. Control Plane Taint Setup & Workload Verification

To ensure compute workload tasks execute strictly on worker nodes (`lab-vm` and `scratch-pc`) while `k8s` remains dedicated to control plane management and driver orchestration, apply the control plane taint:

```bash
kubectl taint nodes k8s node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite
kubectl taint nodes k8s node-role.kubernetes.io/master=true:NoSchedule --overwrite
```

### Benchmark Overview

Multi-node CPU load balancing is verified using [`spark_benchmark.py`](file:///opt/dev/homelab_repo/nodes/k8s/services/spark/spark_benchmark.py), which executes unpruned trigonometric and SHA-512 cryptographic calculations across partitions with a `noop` stream sink.

| Workload | Cluster Topology | Execution Time | Performance Impact |
| :--- | :--- | :--- | :--- |
| **6M Records (6 Partitions)** | Single Node (`scratch-pc`) | **319.65s (5.33 min)** | Baseline (1.00x) |
| **6M Records (6 Partitions)** | Distributed (`scratch-pc` + `lab-vm`) | **147.65s (2.46 min)** | **2.16x Speedup** |
| **30M Records (64 Partitions)** | Max CPU Distributed Cluster | **583.19s (9.72 min)** | **~5.5x Throughput** |

---

## 4. Submitting Distributed Spark Jobs

Run the submission command from `k8s`:

```bash
# Generate 24-hour ServiceAccount authentication token
TOKEN=$(kubectl create token spark -n spark --duration=24h)

# Submit distributed Spark job with container hardening & event logging
/opt/spark/bin/spark-submit \
  --master k8s://https://192.168.50.96:6443 \
  --deploy-mode client \
  --name spark-cpu-benchmark \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=file:///tmp/spark-events \
  --conf spark.kubernetes.container.image=apache/spark:3.5.1 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.kubernetes.authenticate.oauthToken=$TOKEN \
  --conf spark.kubernetes.trust.certificates=true \
  --conf spark.kubernetes.executor.podTemplate.securityContext.runAsNonRoot=true \
  --conf spark.kubernetes.executor.podTemplate.securityContext.runAsUser=10001 \
  --conf spark.kubernetes.executor.podTemplate.securityContext.capabilities.drop=ALL \
  --conf spark.executor.instances=2 \
  --conf spark.executor.cores=1 \
  --conf spark.executor.memory=512m \
  --conf spark.driver.host=192.168.50.96 \
  --conf spark.driver.port=7078 \
  --conf spark.blockManager.port=7079 \
  /opt/spark/spark_benchmark.py
```

### Parameter Tuning Guide

| Parameter | Recommended Setting | Rationale |
| :--- | :--- | :--- |
| **`--master`** | `k8s://https://192.168.50.96:6443` | Directs job submission to k3s API server |
| **`--deploy-mode`** | `client` | Keeps driver CLI output on `k8s` master |
| **`spark.kubernetes.container.image`** | `apache/spark:3.5.1` | Standard Spark runtime image pulled by worker containerd |
| **`spark.kubernetes.trust.certificates`** | `true` | Bypasses self-signed TLS cert errors on local k3s API |
| **`spark.driver.port`** | `7078` | Fixed RPC port for executor-to-driver communication |
| **`spark.blockManager.port`** | `7079` | Fixed BlockManager port for data shuffle exchange |
| **`spark.executor.instances`** | `2` to `4` | Controls total worker pod count across compute nodes |
| **`spark.executor.memory`** | `512m` | Sized to fit comfortably within `scratch-pc` RAM limits |

### Security scan (Caddy + Fail2Ban + CrowdSec + MikroTik)

Job: [`caddy_security_scan.py`](../../nodes/k8s/services/spark/caddy_security_scan.py) · runner: [`run_caddy_security_scan.sh`](../../nodes/k8s/services/spark/run_caddy_security_scan.sh)

| Source | What is scanned |
| :--- | :--- |
| **Caddy** | `401/403/429` on public client IPs — **current + archive** (`*.log` / `*.log.gz`, streamed) |
| **Fail2Ban / CrowdSec** | Ban / scenario lines under `current/` + `archive/` |
| **MikroTik** | `drop_*` firewall rules (esp. `drop_ssh`) + `login failure` — current + archive `.gz` |

Point at reverse-proxy layout (`/mnt/logs` or a staged copy) so both live and rotated trees are included:

```bash
# Live SMB/NFS mount of reverse-proxy logs:
LOGS_ROOT=/mnt/logs ./nodes/k8s/services/spark/run_caddy_security_scan.sh --skip-stage

# Or stage current+archive via rsync (from a host that can SSH reverse-proxy):
./nodes/k8s/services/spark/run_caddy_security_scan.sh
# → stages to /var/spark/logs-root, then:
# python3 … --logs-root /var/spark/logs-root
```

Outputs under `/tmp/caddy-sec-out/`: `findings.json`, `report.txt`, `security_map.html`.  
Gzip archives are **not** unpacked to disk; multi-file `*.tar.gz` snapshots are skipped.

---

## 5. Operations & Web UI Observability

Spark provides two distinct web services for real-time monitoring and historical analysis. They are intentionally designed to share identical UI layouts, DAG execution graphs, and task timelines:

> [!NOTE]
> **Read-Only Telemetry UI**: Both the Spark Live Web UI (port `4040`) and the persistent History Server (port `18080` / `spark.example.com`) are **100% read-only monitoring interfaces**. They display execution telemetry, task timelines, and DAG visualization graphs, but contain **zero** endpoints for job submission, code execution, or cluster configuration modification.

### 1. Ephemeral Driver Live UI (Port 4040)
* **Type**: Embedded HTTP server inside the active PySpark driver JVM process.
* **Lifecycle**: Ephemeral — active strictly while a job is running; automatically terminates when the job completes.
* **Endpoint**: `http://192.168.50.96:4040`

### 2. Persistent History Server Daemon (Port 18080) & Reverse Proxy
* **Type**: Standalone background Java daemon (`/opt/spark/sbin/start-history-server.sh`).
* **Lifecycle**: Persistent (24/7) — replays event JSON log files (`file:///tmp/spark-events`) generated by driver submissions. Updates near real-time during active jobs and retains full historical DAG telemetry indefinitely.
* **Domain Endpoint**: **`https://spark.example.com`** (proxied via Caddy to `192.168.50.96:18080`).

---

## 6. Cluster & Pod Security Hardening

The Spark cluster applies homelab hardening standards across network, pod execution, and proxy layers:

1. **Kubernetes NetworkPolicy Isolation ([network-policy.yaml](file:///opt/dev/homelab_repo/nodes/k8s/services/spark/network-policy.yaml))**:
   Applies an ingress NetworkPolicy in the `spark` namespace allowing executor pod ingress **only** from the driver host (`192.168.50.96`) and peer executor pods, blocking unneeded cluster probing.
   ```bash
   kubectl apply -f nodes/k8s/services/spark/network-policy.yaml
   ```

2. **Pod Security Context & Privilege Dropping**:
   Enforces non-root execution (`uid 10001`) and drops all Linux kernel capabilities (`cap_drop: ALL`):
   ```properties
   spark.kubernetes.executor.podTemplate.securityContext.runAsNonRoot = true
   spark.kubernetes.executor.podTemplate.securityContext.runAsUser = 10001
   spark.kubernetes.executor.podTemplate.securityContext.capabilities.drop = ALL
   ```

3. **Strict Resource Boundaries**:
   Limits executor pod CPU allocation (`1.00`) and memory bounds (`512m`) to prevent host OOM exhaustion.

4. **Automatic Secret Redaction (`spark.redact.regex`)**:
   Redacts sensitive configuration parameters matching `(?i)secret|password|token|key|credentials` with `********` on Web UI views.

5. **LAN-Only Proxy Policy (`access_policy_lan`)**:
   Restricts `https://spark.example.com` to trusted local subnets (`192.168.88.0/24`, `192.168.50.0/24`, `10.5.0.0/24`). External WAN access is rejected automatically with HTTP 403 Forbidden.

---

## 7. CLI Operational Commands

```bash
# Watch active Spark executor pods across cluster nodes
kubectl get pods -n spark -o wide

# View live executor pod logs
kubectl logs -n spark -l spark-role=executor --tail=50 -f

# Check active NetworkPolicies in spark namespace
kubectl get netpol -n spark

# Check node CPU & memory load
kubectl top nodes
```
