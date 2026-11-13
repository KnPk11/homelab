# k8s: Master Bootstrap Guide

> **Hostname:** `k8s` | **IP:** `192.168.50.96` | **Proxmox:** CT 110 | **Type:** Proxmox LXC (Kubernetes Control Plane)

This node (`k8s`, `192.168.50.96`, Proxmox CT 110) is the dedicated **Kubernetes control plane** running a lightweight, hardened single-node `k3s` distribution. It orchestrates distributed analytics jobs (such as Apache Spark) across dedicated worker nodes (`lab-vm` and `scratch-pc`) and provides cluster management interfaces.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configuration directly on the server. Instead, push updates to Git, synchronise the node from `ai-tools` (`sync-nodes <node>`), and apply manifests using `kubectl`.

**Secrets are not in Git.** Encryption keys, kubeconfigs, and runtime secrets live under `/srv/k8s/` or `/srv/spark/` (or are decrypted on-demand via SOPS). After a nuke-and-pave, restore the node's age key from the central secrets vault before decrypting runtime credentials.

---

## 1. System Bootstrap & Provisioning

* Follow the **[Universal Node Bootstrap Guide](../../docs/00_Infrastructure/universal-node-bootstrap.md)** to install base prerequisites and link this node to GitOps.
* **LXC Spec:** [k8s Proxmox LXC](../../docs/00_Infrastructure/proxmox/guests/k8s.md) — VMID 110, unprivileged container with nesting, keyctl, and AppArmor unconfined.
* **k3s Control Plane Initialisation:** Execute the tracked provisioning script [`scripts/setup-k3s.sh`](scripts/setup-k3s.sh) to deploy k3s `v1.30.2+k3s1` with TLS SAN, external IP, secrets encryption, and audit logging:
  ```bash
  bash /opt/homelab-repo/nodes/k8s/scripts/setup-k3s.sh
  ```

---

## 2. Cluster Topology & Compute Workers

The cluster decouples control plane scheduling from heavy compute execution:

| Hostname | Role | IP Address | Infrastructure Type | Scheduling Policy |
| :--- | :--- | :--- | :--- | :--- |
| **`k8s`** | Control Plane | `192.168.50.96` | Proxmox LXC (CT 110) | Tainted (`NoSchedule`) for worker jobs; hosts API, system add-ons, & Headlamp |
| **`lab-vm`** | Compute Worker *(Dormant)* | `192.168.50.91` | Proxmox VM (VM 103) | `k3s-agent` disabled while Spark is idle; untainted when joined |
| **`scratch-pc`** | Auxiliary Worker *(Dormant)* | `192.168.50.85` | Bare-Metal Workstation | `k3s-agent` disabled due to RAM limits; burst worker when joined |

To join worker nodes to this control plane, retrieve the node token from `/var/lib/rancher/k3s/server/node-token` and run the K3s agent installer on each worker node pointing to `https://192.168.50.96:6443` (or run `systemctl enable --now k3s-agent` on previously provisioned workers).

---

## 3. Workloads & Services on this Node

### Headlamp Dashboard

A web-based UI for monitoring cluster state, workloads, and namespaces:
* **Helm Values:** [`services/dashboard/headlamp-values.yaml`](services/dashboard/headlamp-values.yaml) (NodePort `30443` + control-plane tolerations/affinity so Headlamp remains scheduled on `k8s` CT 110)
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
* **Worker SMB Log Mount (`/mnt/caddy-logs`):**
  * Mount Helper: [`services/spark/mount-caddy-logs.sh`](services/spark/mount-caddy-logs.sh) — mounts `//192.168.50.101/logs` read-only via `systemd-creds` (`/etc/credstore.encrypted/smb-logs`) and waits cleanly for DHCP routing and SMB port `445` readiness before invoking `mount.cifs`.
  * Systemd Unit: [`services/spark/mnt-caddy-logs.service`](services/spark/mnt-caddy-logs.service)
  * Installer: [`services/spark/deploy-caddy-logs-mount.sh`](services/spark/deploy-caddy-logs-mount.sh) (supports `--enable` / `--disable`; kept disabled on dormant workers when Spark analytics jobs are idle).
* **Batch Analytics Dispatchers:**
  The distributed data pipelines are authored and maintained in the Data Engineering Portfolio repository (`/opt/de-portfolio/spark/`), submitted to Kubernetes via the tracked shell dispatchers below:
  * [Caddy Geo Map Dispatcher](services/spark/run-caddy-geo-map.sh) — submits `caddy_geo_map.py` to map incoming reverse-proxy traffic geography.
  * [Caddy Security Scan Dispatcher](services/spark/run-caddy-security-scan.sh) — submits `caddy_security_scan.py` to identify exploit probes and anomalous HTTP user agents.
  * [MikroTik Log Insights Dispatcher](services/spark/run-mikrotik-insights.sh) — executes `mikrotik_log_insights.py` to analyse firewall drops and connection spikes.
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
