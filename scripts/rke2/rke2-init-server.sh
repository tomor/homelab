#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/rke2.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/rke2.env"
fi

INSTALL_RKE2_CHANNEL="${INSTALL_RKE2_CHANNEL:-stable}"
RKE2_CNI="${RKE2_CNI:-canal}"
WRITE_KUBECONFIG_MODE="${WRITE_KUBECONFIG_MODE:-0644}"
TLS_SAN="${TLS_SAN:-}"
NODE_IP="${NODE_IP:-}"
ADVERTISE_ADDRESS="${ADVERTISE_ADDRESS:-}"

tmp_config="$(mktemp)"
trap 'rm -f "${tmp_config}"' EXIT

{
  echo "write-kubeconfig-mode: \"${WRITE_KUBECONFIG_MODE}\""
  echo "cni: ${RKE2_CNI}"

  if [[ -n "${NODE_IP}" ]]; then
    echo "node-ip: ${NODE_IP}"
  fi

  if [[ -n "${ADVERTISE_ADDRESS}" ]]; then
    echo "advertise-address: ${ADVERTISE_ADDRESS}"
  fi

  if [[ -n "${RKE2_TOKEN:-}" ]]; then
    echo "token: ${RKE2_TOKEN}"
  fi

  if [[ -n "${TLS_SAN}" ]]; then
    echo "tls-san:"
    IFS=',' read -r -a tls_sans <<< "${TLS_SAN}"
    for san in "${tls_sans[@]}"; do
      trimmed_san="$(echo "${san}" | xargs)"
      if [[ -n "${trimmed_san}" ]]; then
        echo "  - ${trimmed_san}"
      fi
    done
  fi
} > "${tmp_config}"

echo "==> Writing /etc/rancher/rke2/config.yaml"
sudo mkdir -p /etc/rancher/rke2
sudo install -m 0600 "${tmp_config}" /etc/rancher/rke2/config.yaml

echo "==> Installing RKE2 server from channel ${INSTALL_RKE2_CHANNEL}"
curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_CHANNEL="${INSTALL_RKE2_CHANNEL}" sh -

echo "==> Enabling and starting rke2-server"
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

echo "==> Waiting for kubeconfig and node token"
for _ in $(seq 1 60); do
  if sudo test -f /etc/rancher/rke2/rke2.yaml && sudo test -f /var/lib/rancher/rke2/server/node-token; then
    break
  fi
  sleep 5
done

if ! sudo test -f /etc/rancher/rke2/rke2.yaml; then
  echo "ERROR: /etc/rancher/rke2/rke2.yaml was not created. Check: sudo journalctl -u rke2-server -n 100" >&2
  exit 1
fi

if ! sudo test -f /var/lib/rancher/rke2/server/node-token; then
  echo "ERROR: /var/lib/rancher/rke2/server/node-token was not created. Check: sudo journalctl -u rke2-server -n 100" >&2
  exit 1
fi

echo "==> Configuring kubectl for current user"
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/rke2/rke2.yaml "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

server_ip="${NODE_IP:-$(hostname -I | awk '{print $1}')}"
node_token="$(sudo cat /var/lib/rancher/rke2/server/node-token)"

echo ""
echo "✓ First RKE2 server is up."
echo "  Registration endpoint: https://${server_ip}:9345"
echo "  Kubernetes API: https://${server_ip}:6443"
echo ""
echo "  Agent join command:"
echo "  SERVER_URL=https://${server_ip}:9345 RKE2_TOKEN=${node_token} ./rke2-join-agent.sh"
echo ""
echo "  Useful checks:"
echo "  source ~/.bash_aliases"
echo "  kubectl get nodes -o wide"
echo "  sudo journalctl -u rke2-server -f"
