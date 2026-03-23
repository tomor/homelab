# Installing and managing Kubernetes with RKE2

Note: for execution on the hosts, scripts from `scripts/rke2/` are copied to the VM home directory during bootstrap.

## Terraform provisioning

From the repo root:

```bash
make init E=rke2
make apply E=rke2
```

The default `terraform/envs/rke2/terraform.tfvars` provisions:

- three server nodes: `rke2-server-1`, `rke2-server-2`, `rke2-server-3`
- two agent nodes: `rke2-agent-1`, `rke2-agent-2`

Check the VM IPs after apply:

```bash
terraform -chdir=terraform/envs/rke2 output ipv4
```

The Terraform environment now renders a cloud-init file that copies these helpers into `/home/ubuntu/` on each VM:

- `rke2-prepare.sh`
- `rke2-init-server.sh`
- `rke2-join-server.sh`
- `rke2-join-agent.sh`
- `.bash_aliases`
- `rke2.env`

`rke2.env` is generated from Terraform and currently carries the pinned default RKE2 release channel (`v1.31`) plus the CNI choice. The older default is intentional so the lab can exercise RKE2 upgrades. The helper scripts expect these values to come from that generated file during the normal workflow.

## Prepare every node

Run this on every server node and every agent node first:

```bash
./rke2-prepare.sh
```

What it does:

- disables swap
- loads `overlay` and `br_netfilter`
- configures the required sysctl settings
- installs common host packages, including AppArmor tools
- creates `/etc/rancher/rke2/`

Unlike the kubeadm flow in this repo, this script does **not** install containerd or Kubernetes packages directly. RKE2 bundles and manages its own Kubernetes components and container runtime.

## Bootstrap the first server

Log in to the first server node and run:

```bash
./rke2-init-server.sh
```

By default the script:

- installs RKE2 from the Terraform-configured channel (currently `v1.31`)
- writes `/etc/rancher/rke2/config.yaml`
- enables and starts `rke2-server`
- copies `/etc/rancher/rke2/rke2.yaml` to `$HOME/.kube/config`
- prints the node token plus ready-to-use server and agent join commands

The server listens on:

- `9345` for node registration
- `6443` for the Kubernetes API

### Optional server settings

You can override the defaults before running `rke2-init-server.sh`:

```bash
INSTALL_RKE2_CHANNEL=stable RKE2_CNI=cilium ./rke2-init-server.sh
```

If you run the script outside the normal Terraform-generated bootstrap flow and `rke2.env` is not present, you must provide both `INSTALL_RKE2_CHANNEL` and `RKE2_CNI` yourself.

You can also add TLS SANs if you want the server certificate to include a fixed IP or DNS name:

```bash
TLS_SAN="192.168.2.30,rke2-api.lab" ./rke2-init-server.sh
```

For an in-place scale-out, using the current first-server IP as the registration endpoint is acceptable. If you later introduce a stable DNS name or VIP, add it through `TLS_SAN` so the server certificate matches that endpoint.

## Join additional server nodes

On the first server node, read the join token if you need it again:

```bash
sudo cat /var/lib/rancher/rke2/server/node-token
```

On each additional server node, run:

```bash
SERVER_URL=https://<existing-server-ip-or-stable-endpoint>:9345 \
RKE2_TOKEN=<token> \
./rke2-join-server.sh
```

Example:

```bash
SERVER_URL=https://192.168.2.30:9345 \
RKE2_TOKEN=K10d1d0... \
./rke2-join-server.sh
```

The server join script installs `rke2-server`, writes `/etc/rancher/rke2/config.yaml` with the registration endpoint and token, and starts the server service so the node joins the existing control plane.

If `rke2.env` is not present, provide both `INSTALL_RKE2_CHANNEL` and `RKE2_CNI` explicitly before running the join script.

## Taints

RKE2 server nodes are not tainted by default. Taint them manually:
```bash
kubectl taint nodes <server-node-name> node-role.kubernetes.io/control-plane=true:NoSchedule
```

## Join an agent node

On the server node, read the join token if you need it again:

```bash
sudo cat /var/lib/rancher/rke2/server/node-token
```

On the agent node, run:

```bash
SERVER_URL=https://<server-ip>:9345 \
RKE2_TOKEN=<token> \
./rke2-join-agent.sh
```

Example:

```bash
SERVER_URL=https://192.168.2.30:9345 \
RKE2_TOKEN=K10d1d0... \
./rke2-join-agent.sh
```

The agent script installs the RKE2 agent service, writes `/etc/rancher/rke2/config.yaml`, and starts `rke2-agent`.

If `rke2.env` is not present, provide `INSTALL_RKE2_CHANNEL` explicitly before running the join script.

## Access kubectl on the server node

RKE2 ships `kubectl` under:

```bash
/var/lib/rancher/rke2/bin/kubectl
```

This repo's `.bash_aliases` adds that directory to `PATH` and exports:

```bash
KUBECONFIG=/etc/rancher/rke2/rke2.yaml
```

Useful checks:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

## Validate the cluster

After the first server, the additional servers, and the agent nodes are up:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get pods -A -o wide
```

For the default topology you should end up with five nodes total: three `server` nodes and two `agent` nodes.

Then test the existing example workloads from this repo:

```bash
kubectl apply -f workloads/00-namespace.yaml
kubectl apply -f workloads/busybox.yaml
kubectl apply -f workloads/nginx.yaml
kubectl get all -n demo
```

Quick connectivity checks:

```bash
kubectl exec -it -n demo busybox-demo -- nslookup nginx-demo
kubectl exec -it -n demo busybox-demo -- wget -qO- http://nginx-demo
```

## Useful day-2 operations

### Logs

Server:

```bash
sudo journalctl -u rke2-server -f
```

Agent:

```bash
sudo journalctl -u rke2-agent -f
```

### Restart services

Server:

```bash
sudo systemctl restart rke2-server
```

Agent:

```bash
sudo systemctl restart rke2-agent
```

### Upgrade

Upgrade servers first, one at a time, then agents.

Server:

```bash
curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.32.5+rke2r1 sh -
sudo systemctl restart rke2-server
```

Agent:

```bash
curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.32.5+rke2r1 INSTALL_RKE2_TYPE=agent sh -
sudo systemctl restart rke2-agent
```

Prefer upgrading to an explicit newer `INSTALL_RKE2_VERSION=...` so you know exactly what version you are moving to. Be careful not to downgrade: always move forward to a newer RKE2 version, never apply an older version over an existing node.

### etcd snapshots on the single server

RKE2 uses embedded etcd on the server node in this setup. Scheduled snapshots are enabled by default.

List snapshots:

```bash
sudo rke2 etcd-snapshot list
```

Create an on-demand snapshot:

```bash
sudo rke2 etcd-snapshot save --name on-demand
```

Default snapshot storage:

```bash
/var/lib/rancher/rke2/server/db/snapshots
```

### Restore a single-server snapshot

This is destructive for the current cluster state. Stop and verify what you are restoring before you run it.

```bash
sudo systemctl stop rke2-server
sudo rke2 server \
  --cluster-reset \
  --cluster-reset-restore-path=<path-to-snapshot>
sudo systemctl start rke2-server
```

After restore, agent nodes can reconnect normally.

## Troubleshooting

### Check service state

```bash
sudo systemctl status rke2-server
sudo systemctl status rke2-agent
```

### Node did not join

Verify:

- `SERVER_URL` points to `https://<server-ip>:9345`
- the token matches `/var/lib/rancher/rke2/server/node-token`
- the agent hostname is unique
- the server is healthy and reachable on `9345`

### Additional server node does not join

Verify:

- `SERVER_URL` points to `https://<existing-server-ip-or-stable-endpoint>:9345`
- the token matches `/var/lib/rancher/rke2/server/node-token`
- the new server hostname is unique
- the existing server is healthy and reachable on `9345`
- `sudo journalctl -u rke2-server -n 100` on the joining server shows registration progress rather than TLS or token errors

### kubectl not found

Reload aliases or use the full path:

```bash
export PATH=$PATH:/var/lib/rancher/rke2/bin
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes
```

### Clean up a node

The install script provides cleanup helpers:

```bash
sudo rke2-killall.sh
sudo rke2-uninstall.sh
```

These are destructive for that node's RKE2 state.

## Notes

- RKE2 defaults to a packaged CNI. This repo keeps the default as `canal` unless you override it.
- The Kubernetes API is still on `6443`, but new nodes join through the RKE2 registration port `9345`.
- This repo now supports an in-place lab scale-out to multiple RKE2 servers and agents by provisioning the extra VMs in Terraform and joining them with the helper scripts.
