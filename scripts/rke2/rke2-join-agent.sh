#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/rke2.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/rke2.env"
fi

INSTALL_RKE2_CHANNEL="${INSTALL_RKE2_CHANNEL:-stable}"
SERVER_URL="${SERVER_URL:-}"
RKE2_TOKEN="${RKE2_TOKEN:-}"
NODE_IP="${NODE_IP:-}"

if [[ -z "${SERVER_URL}" ]]; then
  echo "ERROR: SERVER_URL must be set, for example https://192.168.2.30:9345" >&2
  exit 1
fi

if [[ -z "${RKE2_TOKEN}" ]]; then
  echo "ERROR: RKE2_TOKEN must be set from the server node token" >&2
  exit 1
fi

tmp_config="$(mktemp)"
trap 'rm -f "${tmp_config}"' EXIT

{
  echo "server: ${SERVER_URL}"
  echo "token: ${RKE2_TOKEN}"

  if [[ -n "${NODE_IP}" ]]; then
    echo "node-ip: ${NODE_IP}"
  fi
} > "${tmp_config}"

echo "==> Writing /etc/rancher/rke2/config.yaml"
sudo mkdir -p /etc/rancher/rke2
sudo install -m 0600 "${tmp_config}" /etc/rancher/rke2/config.yaml

echo "==> Installing RKE2 agent from channel ${INSTALL_RKE2_CHANNEL}"
curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_CHANNEL="${INSTALL_RKE2_CHANNEL}" INSTALL_RKE2_TYPE="agent" sh -

echo "==> Enabling and starting rke2-agent"
sudo systemctl enable rke2-agent.service
sudo systemctl start rke2-agent.service

echo ""
echo "✓ RKE2 agent join requested."
echo "  Follow logs with: sudo journalctl -u rke2-agent -f"
echo "  Verify from the server: kubectl get nodes -o wide"
