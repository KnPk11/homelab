# k8s: Master Bootstrap Guide

> **Hostname:** `k8s` | **IP:** `192.168.50.96` | **Proxmox:** CT 110 | **Type:** Proxmox LXC (Kubernetes Control Plane)

This node (`k8s`, `192.168.50.96`, Proxmox CT 110) is the dedicated **Kubernetes control plane** running a lightweight, hardened single-node `k3s` distribution. It orchestrates distributed analytics jobs (such as Apache Spark) across dedicated worker nodes (`lab-vm` and `scratch-pc`) and provides cluster management interfaces.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configuration directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and apply manifests using `kubectl`.

**Secrets are not in Git.** Encryption keys, kubeconfigs, and runtime secrets live under `/srv/k8s/` or `/srv/spark/` (or are decrypted on-demand via SOPS). After a nuke-and-pave, restore the node's age key from the central secrets vault before decrypting runtime credentials.

---

## 1. System Bootstrap & Provisioning

* Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install base prerequisites and link this node to GitOps.
* **Cron Offset:** Set the `auto_pull_repo.sh` cronjob to run at minute **39** to stagger network load:
  ```bash
  (crontab -l 2>/dev/null; echo "39 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/homelab_autopull.log 2>&1") | sort -u | crontab -
  ```
* **LXC Spec:** [k8s Proxmox LXC](../../docs/00_Infrastructure/proxmox/guests/k8s.md) — VMID 110, unprivileged container with nesting, keyctl, and AppArmor unconfined.
* **k3s Control Plane Initialisation:** Execute the tracked provisioning script [`scripts/setup_k3s.sh`](scripts/setup_k3s.sh) to deploy k3s `v1.30.2+k3s1` with TLS SAN, external IP, secrets encryption, and audit logging:
  ```bash
  bash /opt/homelab-repo/nodes/k8s/scripts/setup_k3s.sh
  ```

---

## 2. Cluster Topology & Compute Workers

The cluster decouples control plane scheduling from heavy compute execution:

| Hostname | Role | IP Address | Infrastructure Type | Scheduling Policy |
| :--- | :--- | :--- | :--- | :--- |
| **`k8s`** | Control Plane | `192.168.50.96` | Proxmox LXC (CT 110) | Tainted (`NoSchedule`) for worker jobs; hosts API & dispatchers |
| **`lab-vm`** | Compute Worker | `192.168.50.91` | Proxmox VM (VM 103) | Untainted compute worker for Spark executors |
| **`scratch-pc`** | Auxiliary Worker | `192.168.50.85` | Bare-Metal Workstation | Burst compute worker for intensive batch analytics |

To join worker nodes to this control plane, retrieve the node token from `/var/lib/rancher/k3s/server/node-token` and run the K3s agent installer on each worker node pointing to `https://192.168.50.96:6443`.

---

## 3. Workloads & Services on this Node

### Headlamp Dashboard

A web-based UI for monitoring cluster state, workloads, and namespaces:
* **Admin & Headlamp RBAC:** [`services/dashboard/dashboard-admin.yaml`](services/dashboard/dashboard-admin.yaml)
* Deployed in the `kubernetes-dashboard` namespace with ClusterRole permissions.

### Apache Spark on Kubernetes

Unified analytics engine utilised for processing reverse-proxy and firewall logs across the homelab:
* **Architecture & Setup Guide:** [Apache Spark on Kubernetes Setup & Administration Guide](../../docs/02_Services/spark/setup.md)
* **Configuration:**
  * SOPS Encrypted Secrets: [`services/spark/spark.env`](services/spark/spark.env)
  * Environment Template: [`services/spark/spark.env.example`](services/spark/spark.env.example)
* **Security & Scheduling Manifests:**
  * Network Policy: [`services/spark/network-policy.yaml`](services/spark/network-policy.yaml) (restricts ingress to driver host `192.168.50.96` and inter-executor pods)
  * Executor Pod Template: [`services/spark/executor-pod-template.yaml`](services/spark/executor-pod-template.yaml) (enforces non-root execution and worker anti-affinity)
* **Batch Analytics Dispatchers:**
  The distributed data pipelines are authored and maintained in the Data Engineering Portfolio repository (`/opt/de-portfolio/spark/`), submitted to Kubernetes via the tracked shell dispatchers below:
  * [Caddy Geo Map Dispatcher](services/spark/run_caddy_geo_map.sh) — submits `caddy_geo_map.py` to map incoming reverse-proxy traffic geography.
  * [Caddy Security Scan Dispatcher](services/spark/run_caddy_security_scan.sh) — submits `caddy_security_scan.py` to identify exploit probes and anomalous HTTP user agents.
  * [MikroTik Log Insights Dispatcher](services/spark/run_mikrotik_insights.sh) — executes `mikrotik_log_insights.py` to analyse firewall drops and connection spikes.
  * **Throughput Benchmark** — submits `spark_benchmark.py` from `/opt/de-portfolio/spark/` to test distributed executor throughput and memory pressure.

---

## 4. Operational Administration & Troubleshooting

### Cluster Health Inspection

```bash
# Verify cluster nodes and versions
kubectl get nodes -o wide

# Verify system and workload pods across all namespaces
kubectl get pods -A

# Check cluster events
kubectl get events -A --sort-by='.metadata.creationTimestamp'
```

### Kubeconfig Management

Kubeconfigs are kept isolated with restricted permissions:
* Local cluster access: `/etc/rancher/k3s/k3s.yaml` (root only, `600`)
* External admin access: `/srv/k8s/output/kubeconfig.yaml` (pre-configured with external IP `192.168.50.96`)

### Service Management

```bash
# Check k3s status
systemctl status k3s

# Restart control plane daemon
systemctl restart k3s

# Inspect recent audit events
tail -f /srv/k8s/data/audit.log
```
