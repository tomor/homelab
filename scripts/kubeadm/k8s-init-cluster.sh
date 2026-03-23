#!/usr/bin/env bash
# k8s-init-cluster.sh — Initialize the first Kubernetes control plane (run ONCE on the first control-plane node)
# Prerequisite: k8s-prepare.sh must have been run on this node first.
set -euo pipefail

POD_CIDR="10.244.0.0/16"
if [[ -z "${CONTROL_PLANE_ENDPOINT:-}" ]]; then
  echo "ERROR: CONTROL_PLANE_ENDPOINT must be set, for example 192.168.2.2:6443 or k8s-api.example.lab:6443" >&2
  exit 1
fi

KUBEADM_INIT_ARGS=(
  --pod-network-cidr="${POD_CIDR}"
  --control-plane-endpoint "${CONTROL_PLANE_ENDPOINT}"
)

echo "==> Initializing Kubernetes control plane (pod CIDR: ${POD_CIDR})"
echo "==> Using stable control-plane endpoint: ${CONTROL_PLANE_ENDPOINT}"
sudo kubeadm init "${KUBEADM_INIT_ARGS[@]}"

echo "==> Configuring kubectl for current user"
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "==> Installing Flannel CNI"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo ""
echo "✓ First control-plane node is up."
echo "  This script is only for the first control-plane node in the cluster."
echo ""
echo "  Worker nodes (after k8s-prepare.sh):"
echo ""
kubeadm token create --print-join-command | sed 's/^/  sudo /'

echo ""
echo "  Additional control-plane nodes (after k8s-prepare.sh):"
echo "    1) On this node, run: sudo kubeadm init phase upload-certs --upload-certs"
echo "    2) On this node, run: sudo kubeadm token create --print-join-command"
echo "    3) On the new control-plane node, run the join command with:"
echo "       --control-plane --certificate-key <key>"

echo ""
echo "========================================"
echo "  OPTIONAL — single-node cluster only"
echo "========================================"
echo "  To allow workloads on the control-plane node, remove the NoSchedule taint:"
echo ""
echo "  kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-"
echo ""
