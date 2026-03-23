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
- `rke2-ingress-nginx-config.yaml`

`rke2.env` is generated from Terraform and currently carries the pinned default RKE2 release channel (`v1.31`) plus the CNI choice. The older default is intentional so the lab can exercise RKE2 upgrades. The helper scripts expect these values to come from that generated file during the normal workflow.

The generated `rke2-ingress-nginx-config.yaml` is installed automatically by the server bootstrap scripts into `/var/lib/rancher/rke2/server/manifests/`. It constrains the bundled `rke2-ingress-nginx` controller to nodes labeled `ingress-ready=true`.

The same Terraform environment now also provisions a dedicated HAProxy VM for the RKE2 cluster. After `make apply E=rke2`, read the LB IP from:

```bash
terraform -chdir=terraform/envs/rke2 output -raw load_balancer_ipv4
```

Then add a manual `/etc/hosts` entry on your workstation for:

```text
<load-balancer-ip> rke2-api.home.arpa nginx-ingress-demo.rke2.home.arpa
```

Use that LB IP inside the cluster VMs for `SERVER_URL` and `RKE2_LB_IP`. The `.home.arpa` hostname is only for workstation access.

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
RKE2_LB_IP=<rke2-lb-ip> ./rke2-init-server.sh
```

By default the script:

- installs RKE2 from the Terraform-configured channel (currently `v1.31`)
- writes `/etc/rancher/rke2/config.yaml`
- enables and starts `rke2-server`
- copies `/etc/rancher/rke2/rke2.yaml` to `$HOME/.kube/config`
- prints the node token plus ready-to-use server and agent join commands
- requires `RKE2_LB_IP` so the cluster always bootstraps against the HAProxy endpoint

The server listens on:

- `9345` for node registration
- `6443` for the Kubernetes API

### Optional server settings

You can override the defaults before running `rke2-init-server.sh`:

```bash
INSTALL_RKE2_CHANNEL=stable RKE2_CNI=cilium ./rke2-init-server.sh
```

If you run the script outside the normal Terraform-generated bootstrap flow and `rke2.env` is not present, you must provide both `INSTALL_RKE2_CHANNEL` and `RKE2_CNI` yourself.

`RKE2_LB_IP` is mandatory. By default, the Terraform-generated `rke2.env` sets `RKE2_API_HOSTNAME=rke2-api.home.arpa` for workstation-facing access. When you set `RKE2_LB_IP=<rke2-lb-ip>` before running the helper script, it adds both the LB IP and the hostname as TLS SANs and prints join commands that use the HAProxy VM IP.

You can also override the TLS SANs manually if you want the server certificate to include a different IP or DNS name:

```bash
RKE2_LB_IP=<rke2-lb-ip> TLS_SAN="<rke2-lb-ip>,rke2-api.home.arpa" ./rke2-init-server.sh
```

For HA in this repo, use the HAProxy VM IP from day 1 inside the cluster VMs. The optional hostname `rke2-api.home.arpa` is for workstation access and should resolve to the same HAProxy VM.

## Join additional server nodes

On the first server node, read the join token if you need it again:

```bash
sudo cat /var/lib/rancher/rke2/server/node-token
```

On each additional server node, run:

```bash
SERVER_URL=https://<rke2-lb-ip>:9345 \
RKE2_LB_IP=<rke2-lb-ip> \
RKE2_TOKEN=<token> \
./rke2-join-server.sh
```

Example:

```bash
SERVER_URL=https://<rke2-lb-ip>:9345 \
RKE2_LB_IP=<rke2-lb-ip> \
RKE2_TOKEN=K10d1d0... \
./rke2-join-server.sh
```

The server join script installs `rke2-server`, writes `/etc/rancher/rke2/config.yaml` with the registration endpoint and token, adds default TLS SANs for the LB IP plus `rke2-api.home.arpa`, and starts the server service so the node joins the existing control plane.

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
SERVER_URL=https://<rke2-lb-ip>:9345 \
RKE2_TOKEN=<token> \
./rke2-join-agent.sh
```

Example:

```bash
SERVER_URL=https://<rke2-lb-ip>:9345 \
RKE2_TOKEN=K10d1d0... \
./rke2-join-agent.sh
```

The agent script installs the RKE2 agent service, writes `/etc/rancher/rke2/config.yaml`, and starts `rke2-agent`.

The generated config also labels each agent node with `ingress-ready=true`, which is how the bundled RKE2 nginx ingress controller is constrained to agent nodes only.

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
kubectl apply -f workloads/nginx-nodeport.yaml
kubectl apply -f workloads/nginx-ingress.yaml
kubectl get all -n demo
```

Quick connectivity checks:

```bash
kubectl exec -it -n demo busybox-demo -- nslookup nginx-demo
kubectl exec -it -n demo busybox-demo -- wget -qO- http://nginx-demo
```

To reach the NodePort example directly from your workstation:

```bash
kubectl get nodes -o wide
curl http://<node-ip>:30080
```

To reach the ingress example from your workstation:

```bash
curl http://nginx-ingress-demo.rke2.home.arpa
```

The HAProxy VM now forwards:

- `6443` to the RKE2 server nodes for the Kubernetes API
- `9345` to the RKE2 server nodes for node registration
- `80` to the RKE2 agent nodes for ingress traffic

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

Do not skip intermediate minor versions when upgrading. The reason is k8s skew policy https://kubernetes.io/releases/version-skew-policy/

1. Check release notes: https://docs.rke2.io/release-notes/v1.32.X
2. Back up etcd / datastore state before touching the control plane.
```bash
sudo rke2 etcd-snapshot save
```
3. For each node:
  a) Cordon and drain the node
  Execute from local computer, not from the Server node!

  Note: Draining the first CP node took a lot of time, stuck?. I've started the command from the server node itself. Then I canceled it after some time. Then upgraded. Some pods got stuck in terminating state (dns, metrics-server, snapshot-controller)
```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```
  b) stop/upgrade/start the RKE2 service on that node
    Server:
```bash
curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.32.13+rke2r1 sh -
sudo systemctl restart rke2-server
```

    Agent:
```bash
curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.32.13+rke2r1 INSTALL_RKE2_TYPE=agent sh -
sudo systemctl restart rke2-agent
```
  c) wait until the node returns Ready
  d) uncordon when appropriate
  ```bash
  kubectl uncordon <node>
  ```


#### Upgrade notes

##### Crashing helm charts
After upgrade of first server node, there are some helm charts crashing. That's expected, it fixes itself after continuing the upgrade on the second server node.
```
k get pod -A -owide | grep -v Running
NAMESPACE     NAME                                                   READY   STATUS              RESTARTS      AGE     IP             NODE            NOMINATED NODE   READINESS GATES
kube-system   helm-install-rke2-canal-xnv5t                          0/1     CrashLoopBackOff    9 (62s ago)   21m     192.168.2.43   rke2-server-3   <none>           <none>
kube-system   helm-install-rke2-coredns-zrpz6                        0/1     CrashLoopBackOff    9 (45s ago)   21m     192.168.2.43   rke2-server-3   <none>           <none>
kube-system   helm-install-rke2-ingress-nginx-5m25w                  0/1     ContainerCreating   0             21m     <none>         rke2-agent-1    <none>           <none>
kube-system   helm-install-rke2-snapshot-controller-crd-mm4p2        0/1     ContainerCreating   0             21m     <none>         rke2-agent-1    <none>           <none>

k logs -n kube-system helm-install-rke2-canal-xnv5t
Error: UPGRADE FAILED: chart requires kubeVersion: >= v1.32.13 which is incompatible with Kubernetes v1.31.14+rke2r1
```


##### Donwgrade!
Prefer upgrading to an explicit newer `INSTALL_RKE2_VERSION=...` so you know exactly what version you are moving to. Be careful not to downgrade.


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

### Restore a etcd snapshot

Docs for HA setup: https://docs.rke2.io/datastore/backup_restore?etcdsnap=Multiple+Servers

More info: https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#restoring-an-etcd-cluster

Caution:
If any API servers are running in your cluster, you should not attempt to restore instances of etcd. Instead, follow these steps to restore etcd:

- stop all API server instances
- restore state in all etcd instances
- restart all API server instances

The Kubernetes project also recommends restarting Kubernetes components (kube-scheduler, kube-controller-manager, kubelet) to ensure that they don't rely on some stale data. In practice the restore takes a bit of time. During the restoration, critical components will lose leader lock and restart themselves.


This is destructive for the current cluster state. Stop and verify what you are restoring before you run it.

```bash
sudo systemctl stop rke2-server
sudo rke2 server \
  --cluster-reset \
  --cluster-reset-restore-path=<path-to-snapshot>
sudo systemctl start rke2-server
```

After restore, agent nodes can reconnect normally.

#### etcd restore issue:
In my case the workloads stopped responding (nginx via node port not reachable), there was a problem with pod networking.
The readiness probes were failing on agent nodes.
I've restart the rke2-agent which didn't fix the issue.
Then restarted canal (CNI) which fixed the issue.
```
sudo systemctl restart rke2-agent
```
```
kubectl -n kube-system rollout restart ds/rke2-canal
kubectl -n kube-system rollout status ds/rke2-canal
```

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


## Good to know

### Stopping rke2 supervisor process
`systemctl stop rke2-server` stops the RKE2 supervisor process, kubelet, and containerd, but the pods that were already running stay running, including `kube-proxy` and the control-plane static pods.
