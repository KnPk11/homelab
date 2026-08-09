#!/bin/bash
# =============================================================================
# setup_k3s.sh
# Version: 1.0
# Date: 2026-08-09
#
# Provision & Harden k3s Control Plane Node (k8s CT 110 - 192.168.50.96)
# =============================================================================
set -e

K3S_NODE_IP="192.168.50.96"
K3S_VERSION="v1.30.2+k3s1"

echo "=== Initialising Hardened k3s Control Plane Setup ==="

# 1. Ensure storage directories exist
mkdir -p /srv/k8s/{data,output}

# 2. Deploy or update k3s with security hardening flags
export INSTALL_K3S_VERSION="${K3S_VERSION}"

curl -sfL https://get.k3s.io | sh -s - server \
  --disable=traefik \
  --tls-san="${K3S_NODE_IP}" \
  --node-external-ip="${K3S_NODE_IP}" \
  --data-dir=/srv/k8s/data \
  --write-kubeconfig-mode=600 \
  --secrets-encryption \
  --kube-apiserver-arg=anonymous-auth=false \
  --kube-apiserver-arg=audit-log-path=/srv/k8s/data/audit.log \
  --kube-apiserver-arg=audit-log-maxage=30 \
  --kube-apiserver-arg=audit-log-maxbackup=10 \
  --kube-apiserver-arg=audit-log-maxsize=100

# 3. Export external kubeconfig for remote clients
cp -f /etc/rancher/k3s/k3s.yaml /srv/k8s/output/kubeconfig.yaml
sed -i "s/127.0.0.1/${K3S_NODE_IP}/g" /srv/k8s/output/kubeconfig.yaml
chmod 600 /srv/k8s/output/kubeconfig.yaml

echo "=== k3s Control Plane Hardening Complete ==="
echo "Node IP: ${K3S_NODE_IP}"
echo "Kubeconfig: /srv/k8s/output/kubeconfig.yaml (mode 600)"
echo "Audit Log: /srv/k8s/data/audit.log"
