#!/usr/bin/env bash
# k8s-init-controlplane.sh — Initialize the Kubernetes control plane (run ONCE on control-plane node)
# Prerequisite: k8s-prepare.sh must have been run on this node first.
set -euo pipefail

POD_CIDR="192.168.0.0/16"

echo "==> Initializing Kubernetes control plane (pod CIDR: ${POD_CIDR})"
sudo kubeadm init --pod-network-cidr="${POD_CIDR}"

echo "==> Configuring kubectl for current user"
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "==> Installing Calico CNI"
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml

echo ""
echo "✓ Control plane is up. Run the following on each worker node (after k8s-prepare.sh):"
echo ""
kubeadm token create --print-join-command | sed 's/^/  sudo /'

echo ""
echo "========================================"
echo "  OPTIONAL — single-node cluster only"
echo "========================================"
echo "  To allow workloads on the control-plane node, remove the NoSchedule taint:"
echo ""
echo "  kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-"
echo ""
