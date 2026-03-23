#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/rke2.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/rke2.env"
fi

echo "==> Disabling swap"
sudo swapoff -a
sudo sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab

echo "==> Loading required kernel modules"
cat <<'EOF' | sudo tee /etc/modules-load.d/rke2.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "==> Setting sysctl values for Kubernetes networking"
cat <<'EOF' | sudo tee /etc/sysctl.d/90-rke2.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

echo "==> Installing host prerequisites"
sudo apt-get update -y
sudo apt-get install -y apt-transport-https apparmor apparmor-utils ca-certificates curl gnupg

echo "==> Preparing RKE2 config directory"
sudo mkdir -p /etc/rancher/rke2

echo ""
echo "✓ Host preparation complete."
echo "  Next step on the first server node: run ./rke2-init-server.sh"
echo "  Next step on additional server nodes: wait for the server token, then run ./rke2-join-server.sh"
echo "  Next step on agent nodes: wait for the server token, then run ./rke2-join-agent.sh"
