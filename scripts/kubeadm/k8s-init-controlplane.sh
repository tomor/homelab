#!/usr/bin/env bash
# k8s-init-controlplane.sh — Initialize the first Kubernetes control plane (run ONCE on the first control-plane node)
# Prerequisite: k8s-prepare.sh must have been run on this node first.
set -euxo pipefail

POD_CIDR="192.168.0.0/16"
CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT:-}"
KUBEADM_INIT_ARGS=(--pod-network-cidr="${POD_CIDR}")

if [[ -n "${CONTROL_PLANE_ENDPOINT}" ]]; then
  KUBEADM_INIT_ARGS+=(--control-plane-endpoint "${CONTROL_PLANE_ENDPOINT}")
fi

echo "==> Initializing Kubernetes control plane (pod CIDR: ${POD_CIDR})"
if [[ -n "${CONTROL_PLANE_ENDPOINT}" ]]; then
  echo "==> Using stable control-plane endpoint: ${CONTROL_PLANE_ENDPOINT}"
else
  echo "==> No CONTROL_PLANE_ENDPOINT set"
  echo "    This is fine for a single control-plane cluster,"
  echo "    but you will not be able to add more control-plane nodes later."
fi
sudo kubeadm init "${KUBEADM_INIT_ARGS[@]}"

echo "==> Configuring kubectl for current user"
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "==> Installing Calico CNI"
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml

echo ""
echo "✓ First control-plane node is up."
echo "  This script is only for the first control-plane node in the cluster."
echo ""
echo "  Worker nodes (after k8s-prepare.sh):"
echo ""
kubeadm token create --print-join-command | sed 's/^/  sudo /'

echo ""
echo "  Additional control-plane nodes (after k8s-prepare.sh):"
if [[ -n "${CONTROL_PLANE_ENDPOINT}" ]]; then
  echo "    1) On this node, run: sudo kubeadm init phase upload-certs --upload-certs"
  echo "    2) On this node, run: sudo kubeadm token create --print-join-command"
  echo "    3) On the new control-plane node, run the join command with:"
  echo "       --control-plane --certificate-key <key>"
else
  echo "    To support additional control-plane nodes, recreate the cluster with:"
  echo "      CONTROL_PLANE_ENDPOINT=<stable DNS name or IP:6443> ./k8s-init-controlplane.sh"
fi

echo ""
echo "========================================"
echo "  OPTIONAL — single-node cluster only"
echo "========================================"
echo "  To allow workloads on the control-plane node, remove the NoSchedule taint:"
echo ""
echo "  kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-"
echo ""
