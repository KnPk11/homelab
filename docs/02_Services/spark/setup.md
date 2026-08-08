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
| **`4040`** | TCP | Spark Web UI | Driver job UI (active during job runs) |
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

# Submit distributed Spark job to k3s API
/opt/spark/bin/spark-submit \
  --master k8s://https://192.168.50.96:6443 \
  --deploy-mode client \
  --name spark-cpu-benchmark \
  --conf spark.kubernetes.container.image=apache/spark:3.5.1 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.kubernetes.authenticate.oauthToken=$TOKEN \
  --conf spark.kubernetes.trust.certificates=true \
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

---

## 5. Operations & Web UI Observability

Spark provides two web interfaces for real-time monitoring and historical analysis:

### 1. Live Job Web UI (Port 4040)
When a Spark job is actively executing, the driver process hosts a live web application at `http://192.168.50.96:4040`. It provides real-time visualizations of active stages, DAG execution graphs, task distribution, and executor CPU/memory metrics.

### 2. Persistent History Server (Port 18080)
To inspect completed job performance, task timelines, and historical DAGs after a job finishes:

```bash
# 1. Enable event logging in spark-submit
/opt/spark/bin/spark-submit \
  ... \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=file:///tmp/spark-events \
  /opt/spark/spark_benchmark.py

# 2. Start persistent History Server daemon on k8s
/opt/spark/sbin/start-history-server.sh

# 3. Access persistent UI in browser
http://192.168.50.96:18080
```

### CLI Operational Commands

```bash
# Watch active Spark executor pods across cluster nodes
kubectl get pods -n spark -o wide

# View live executor pod logs
kubectl logs -n spark -l spark-role=executor --tail=50 -f

# Check node CPU & memory load
kubectl top nodes
```
