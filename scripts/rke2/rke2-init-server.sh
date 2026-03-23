#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/rke2.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/rke2.env"
fi

INSTALL_RKE2_CHANNEL="${INSTALL_RKE2_CHANNEL:-}"
RKE2_CNI="${RKE2_CNI:-}"
WRITE_KUBECONFIG_MODE="${WRITE_KUBECONFIG_MODE:-0644}"
RKE2_LB_IP="${RKE2_LB_IP:-}"
RKE2_API_HOSTNAME="${RKE2_API_HOSTNAME:-}"
if [[ -n "${TLS_SAN:-}" ]]; then
  TLS_SAN="${TLS_SAN}"
else
  san_values=()
  if [[ -n "${RKE2_LB_IP}" ]]; then
    san_values+=("${RKE2_LB_IP}")
  fi
  if [[ -n "${RKE2_API_HOSTNAME}" ]]; then
    san_values+=("${RKE2_API_HOSTNAME}")
  fi
  TLS_SAN="$(IFS=,; echo "${san_values[*]}")"
fi
NODE_IP="${NODE_IP:-}"
ADVERTISE_ADDRESS="${ADVERTISE_ADDRESS:-}"

if [[ -z "${INSTALL_RKE2_CHANNEL}" ]]; then
  echo "ERROR: INSTALL_RKE2_CHANNEL must be set, typically via the Terraform-generated rke2.env file" >&2
  exit 1
fi

if [[ -z "${RKE2_CNI}" ]]; then
  echo "ERROR: RKE2_CNI must be set, typically via the Terraform-generated rke2.env file" >&2
  exit 1
fi

if [[ -z "${RKE2_LB_IP}" ]]; then
  echo "ERROR: RKE2_LB_IP must be set to the RKE2 HAProxy VM IP, for example 192.168.2.30" >&2
  exit 1
fi

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
# This is ok for lab environment, but not for production.
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

registration_endpoint="${RKE2_LB_IP}"
node_token="$(sudo cat /var/lib/rancher/rke2/server/node-token)"

echo ""
echo "✓ First RKE2 server is up."
echo "  Registration endpoint: https://${registration_endpoint}:9345"
echo "  Kubernetes API: https://${registration_endpoint}:6443"
echo ""
echo "  Additional server join command:"
echo "  SERVER_URL=https://${registration_endpoint}:9345 RKE2_TOKEN=${node_token} ./rke2-join-server.sh"
echo ""
echo "  Agent join command:"
echo "  SERVER_URL=https://${registration_endpoint}:9345 RKE2_TOKEN=${node_token} ./rke2-join-agent.sh"
echo ""
echo "  Useful checks:"
echo "  source ~/.bash_aliases"
echo "  kubectl get nodes -o wide"
echo "  sudo journalctl -u rke2-server -f"
