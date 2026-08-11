# K3s Lightweight Kubernetes Setup & Administration Guide

> [!NOTE]
> #K3s #Kubernetes #Dashboard #Homelab

## 1. Description

K3s is a lightweight, fully CNCF-certified Kubernetes distribution packaged as a single binary to run containerised workloads efficiently across homelab nodes. This guide covers cluster provisioning, control plane security hardening, worker node compute expansion, and Headlamp web UI administration.

## 2. Overview & Network Ports

* **Cluster Engine**: `k3s` (Rancher Lightweight Kubernetes `v1.30.2+k3s1`)
* **Control Plane Host**: `[CONTROL-PLANE-HOST]` (`[CONTROL-PLANE-IP]`)
* **Worker Nodes**: Compute / worker nodes running the `k3s` agent
* **Storage Location**: `/srv/k8s/`
* **Provisioning Script**: `nodes/k8s/scripts/setup_k3s.sh`
* **Dashboard Admin Manifest**: `nodes/k8s/services/dashboard/dashboard-admin.yaml`
* **Reverse Proxy**: Caddy → NodePort (apps + Headlamp UI)

### Required Port Allocations

| Port | Protocol | Description | Notes |
| :--- | :--- | :--- | :--- |
| **`6443`** | TCP | K8s API Server | `kubectl`, `k9s`, & agent join |
| **`10250`**| TCP | Kubelet API | Metrics & log streaming |
| **`8472`** | UDP | Flannel VXLAN | Pod overlay network between nodes |
| **`30363`**| TCP | NodePort | Sample application ingress target |
| **`30443`**| TCP | NodePort | Headlamp Web UI HTTPS (via reverse proxy) |
| **`8089` / `8445`** | TCP | Ingress HTTP / HTTPS | Traefik / ingress controller (optional) |

## 3. Control Plane Installation (Bare-Metal / LXC)

On the dedicated control-plane host (`[CONTROL-PLANE-IP]`):

```bash
# Run version-controlled hardened setup script
/opt/dev/homelab_repo/nodes/k8s/scripts/setup_k3s.sh
```

### Worker Node Join (Multi-Node Compute)

To join compute nodes to the cluster:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.30.2+k3s1 \
  K3S_URL=https://[CONTROL-PLANE-IP]:6443 \
  K3S_TOKEN=<NODE_TOKEN> sh -
```

Retrieve the **worker join** token from the control plane:

```bash
cat /srv/k8s/data/server/node-token
```

> [!IMPORTANT]
> **Do not use the node join token for Dashboard login.**
>
> `/srv/k8s/data/server/node-token` is only for `k3s` agent join. Dashboard login needs the ServiceAccount bearer token from `admin-user-token` (see §8).

## 4. Cluster Security Hardening & Controls

The k3s control plane enables these hardening layers via `setup_k3s.sh`:

- **Secrets Encryption at Rest (`--secrets-encryption`)**: All Kubernetes `Secret` objects stored under `/srv/k8s/data/server/db/` are encrypted using keys under `/srv/k8s/data/server/cred/encryption-config.json`.
- **Strict Kubeconfig File Permissions (`--write-kubeconfig-mode=600`)**: Restricts `/etc/rancher/k3s/k3s.yaml` to mode `600` (`root:root`), so unprivileged host users cannot read cluster credentials.
- **Control Plane Audit Logging**: Audit log path: `/srv/k8s/data/audit.log` (30-day retention, 100 MB rotation).
- **Control Plane Taint & Worker Isolation**: Keeps heavy workloads off the control plane node:

  ```bash
  kubectl taint nodes k8s node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite
  kubectl taint nodes k8s node-role.kubernetes.io/master=true:NoSchedule --overwrite
  ```

> [!NOTE]
> **Anonymous API auth**
>
> `--kube-apiserver-arg=anonymous-auth=false` is **not** currently applied. It was tried during Dashboard bring-up and removed because it complicated unauthenticated bootstrap/discovery paths. Token login itself depends on a valid ServiceAccount secret (see §8), not on leaving anonymous auth enabled. Revisit only after retesting Dashboard login end-to-end.

## 5. Universal Configuration & Workload Manifest (`app-deployment.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: default
  labels:
    app: sample-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: sample-app
        image: python:3.11-slim
        command: ["python3", "-u", "app.py"]
        workingDir: /app
        ports:
        - containerPort: 33363
        volumeMounts:
        - name: app-storage
          mountPath: /app
      volumes:
      - name: app-storage
        hostPath:
          path: /srv/k8s/sample-app
          type: DirectoryOrCreate
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app-service
  namespace: default
spec:
  type: NodePort
  selector:
    app: sample-app
  ports:
  - port: 33363
    targetPort: 33363
    nodePort: 30363
```

## 6. Client CLI & Administration (`kubectl` & `k9s`)

To administer the cluster from your workstation:

```bash
mkdir -p ~/.kube
ssh root@[CONTROL-PLANE-IP] "cat /srv/k8s/output/kubeconfig.yaml" > ~/.kube/config

# Verify cluster status
kubectl get nodes -o wide
kubectl get pods -A -o wide
k9s
```

## 7. Reverse Proxy Integration

Expose NodePort services (such as Headlamp) through Caddy or another reverse proxy:

```caddy
k8s.example.com {
    reverse_proxy [CONTROL-PLANE-IP]:30443
}
```

## 8. Kubernetes Web Dashboard (Headlamp v0.44.0) & Token Login

### Deployment & Engine Overview

The cluster utilizes **Headlamp** (`kubernetes-sigs/headlamp` v0.44.0), the official modern Kubernetes web UI maintained under **CNCF SIG-UI**:

```bash
# Deployed via Helm into kubernetes-dashboard namespace
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm upgrade --install headlamp headlamp/headlamp \
  --namespace kubernetes-dashboard \
  --create-namespace \
  --set service.type=NodePort \
  --set service.nodePort=30443 \
  --set config.unsafeUseServiceAccountToken=false
```

### Deploy admin identity & cluster role bindings

Kubernetes **1.24+** (including this k3s `v1.30.2`) no longer auto-creates long-lived ServiceAccount secrets. Apply the admin identity manifest:

```bash
kubectl apply -f /opt/dev/homelab_repo/nodes/k8s/services/dashboard/dashboard-admin.yaml
```

That manifest creates:

| Object | Purpose |
| :--- | :--- |
| `ServiceAccount/admin-user` | Identity used for static token generation |
| `Secret/admin-user-token` | Long-lived bearer token (type `kubernetes.io/service-account-token`) |
| `ClusterRoleBinding/admin-user` | Binds `admin-user` SA to `cluster-admin` |
| `ClusterRoleBinding/headlamp-admin` | Binds Headlamp pod SA to `cluster-admin` |

### Retrieve the Dashboard login token

On the control plane (or any host with working kubeconfig):

```bash
kubectl -n kubernetes-dashboard get secret admin-user-token \
  -o jsonpath='{.data.token}' | base64 -d
echo
```

Paste that full 256-bit JWT into the Headlamp **Token** field at `https://k8s.example.com/` (LAN/VPN only).

> [!TIP]
> **Vaultwarden Storage Workflow**
> Store this long 256-bit JWT in Vaultwarden behind 2FA. For a solo homelab operator, keeping your static admin token in your password manager is the cleanest workflow (avoiding the friction of generating short-lived 1-hour tokens).

> [!TIP]
> **Quick check that the token is valid against the API**
>
> ```bash
> TOKEN=$(kubectl -n kubernetes-dashboard get secret admin-user-token \
>   -o jsonpath='{.data.token}' | base64 -d)
> curl -sk -o /dev/null -w "%{http_code}\n" \
>   -H "Authorization: Bearer $TOKEN" \
>   https://[CONTROL-PLANE-IP]:6443/api/v1/namespaces
> ```
>
> Expect `200`. If that fails, fix the secret/RBAC before debugging Caddy.


## 9. Operational Cheat Sheet

```bash
# Cluster health & node status
kubectl get nodes,pods -A -o wide

# Inspect audit logs (on control plane)
tail -f /srv/k8s/data/audit.log

# Worker join token (agents only — NOT Dashboard)
cat /srv/k8s/data/server/node-token

# Dashboard login token
kubectl -n kubernetes-dashboard get secret admin-user-token \
  -o jsonpath='{.data.token}' | base64 -d; echo

# Dashboard workload status
kubectl -n kubernetes-dashboard get pods,svc,sa,secret
```
