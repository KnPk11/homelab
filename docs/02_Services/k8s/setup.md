# K3s Lightweight Kubernetes Setup & Administration Guide

A clean, minimal reference guide for deploying, managing, and operating a `k3s` Kubernetes cluster in your homelab environment.

---

## 1. Overview & Network Ports

* **Cluster Engine**: `k3s` (Rancher Lightweight Kubernetes `v1.30.2+k3s1`)
* **Deployment Options**: Docker Compose containerised deployment **or** native Bare-Metal / LXC setup.
* **Storage Location**: `/srv/k8s/`
* **Reverse Proxy**: Caddy → NodePort (e.g., `30363`)

### Required Port Allocations

| Port | Protocol | Description | Notes |
| :--- | :--- | :--- | :--- |
| **`6443`** | TCP | K8s API Server | `kubectl`, `k9s`, & agent join |
| **`10250`**| TCP | Kubelet API | Metrics & log streaming |
| **`8472`** | UDP | Flannel VXLAN | Pod overlay network between nodes |
| **`30363`**| TCP | NodePort | Sample application ingress target |
| **`8089` / `8445`** | TCP | Ingress HTTP / HTTPS | Traefik / ingress controller (optional) |

---

## 2. Setup Option A: Docker Compose Deployment

Use Docker Compose for quick containerised control-plane deployment using host network mode.

### `docker-compose.yml`

```yaml
version: '3.8'

services:
  k3s-server:
    image: rancher/k3s:v1.30.2-k3s1
    container_name: k3s-server
    ports:
      - "6443:6443"                    # Kubernetes API Server (kubectl & k9s)
      - "8089:80"                      # Ingress HTTP
      - "8445:443"                     # Ingress HTTPS
      - "10250:10250"                  # Kubelet API
      - "8472:8472/udp"                # Flannel Overlay Network
      - "30363:30363"                  # Kubernetes NodePorts (e.g. 30363)
    network_mode: host                 # Directly binds to host network interface
    command: 
      - server
      - --disable=traefik              # Keep lightweight
      - --tls-san=192.168.50.95        # Allows kubectl connection via host IP
      - --node-external-ip=192.168.50.95  # Advertises host IP to external worker nodes
    privileged: true
    environment:
      - K3S_KUBECONFIG_OUTPUT=/output/kubeconfig.yaml
      - K3S_KUBECONFIG_MODE=666
    volumes:
      - /srv/k8s/data:/var/lib/rancher/k3s
      - /srv/k8s/output:/output
    restart: unless-stopped

volumes:
  k3s-data:
  k3s-output:
```

### Launch Command

```bash
mkdir -p /srv/k8s/{data,output}
docker compose up -d
```

---

## 3. Setup Option B: Bare-Metal / LXC Deployment

Use native installation for dedicated Proxmox LXCs or bare-metal Linux nodes.

### Bare-Metal Installation Script

On the target control-plane host:

```bash
mkdir -p /srv/k8s/{data,output}

export INSTALL_K3S_VERSION=v1.30.2+k3s1
curl -sfL https://get.k3s.io | sh -s - server \
  --disable=traefik \
  --tls-san=192.168.50.96 \
  --node-external-ip=192.168.50.96 \
  --data-dir=/srv/k8s/data \
  --write-kubeconfig-mode=644

# Export kubeconfig for remote clients
cp -f /etc/rancher/k3s/k3s.yaml /srv/k8s/output/kubeconfig.yaml
sed -i 's/127.0.0.1/192.168.50.96/g' /srv/k8s/output/kubeconfig.yaml
```

### Worker Node Join (Optional Multi-Node)

To join worker compute nodes to the cluster:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.30.2+k3s1 \
  K3S_URL=https://192.168.50.96:6443 \
  K3S_TOKEN=<NODE_TOKEN> sh -
```

*(Retrieve the token from `/srv/k8s/data/server/node-token` on the master host).*

---

## 4. Universal Configuration & Workload Deployment

The following pattern applies universally regardless of whether K3s was deployed via Docker Compose or Bare-Metal.

### Generic Workload Manifest (`app-deployment.yaml`)

A starting point template demonstrating a Deployment with host storage and a NodePort Service:

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

### Applying Workloads

```bash
kubectl apply -f app-deployment.yaml
kubectl rollout status deploy/sample-app
```

---

## 5. Reverse Proxy Integration (Caddy)

To expose your NodePort workload externally through Caddy:

```caddy
app.example.com {
    import common-headers
    import common-logging

    reverse_proxy 192.168.50.96:30363
}
```

---

## 6. Client CLI Setup (`kubectl` & `k9s`)

To administer the cluster from your workstation or remote CLI:

```bash
mkdir -p ~/.kube
ssh root@<K3S_HOST_IP> "cat /srv/k8s/output/kubeconfig.yaml" > ~/.kube/config

# Verify cluster status
kubectl get nodes -o wide
kubectl get pods -A -o wide
k9s
```

---

## 7. Operational Cheat Sheet

```bash
# Cluster Health
kubectl get nodes,pods -A -o wide

# Check Local NodePort Endpoint
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:30363/

# Retrieve Worker Join Token
cat /srv/k8s/data/server/node-token
```
