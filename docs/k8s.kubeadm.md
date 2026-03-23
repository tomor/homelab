# Installing k8s manually via kubeadm

Note: There are shell scripts now which are copied to the VM automatically which are doing exactly this:

## Prepare the host

1) Disable swap

```
sudo swapoff -a
sudo sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab
```

2) Load required kernel modules

```
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

3) Set sysctl values for Kubernetes networking

```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

4) Install containerd

```
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y containerd.io
```

5) Configure containerd to use systemd cgroups

```
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

6) Install kubeadm, kubelet, kubectl

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

## Initialize the first control-plane node

Run this once on the first control-plane node only, and always provide a stable `CONTROL_PLANE_ENDPOINT`.

With the helper script in this repo:

```bash
CONTROL_PLANE_ENDPOINT=192.168.2.2:6443 ./k8s-init-cluster.sh
```

With raw `kubeadm init`:

for Calico default CIDR:
```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --control-plane-endpoint 192.168.2.2:6443
```

for Flannel default CIDR:
```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint 192.168.2.2:6443
```

The exact `--pod-network-cidr` depends on the CNI plugin you choose. kubeadm installation and cluster creation are separate steps in the official docs.

A stable endpoint is the address all nodes use for the Kubernetes API server. In this homelab, a fixed first control-plane node IP and port such as `192.168.2.2:6443` is acceptable if you do not have a load balancer yet. For better HA later, that endpoint should usually be a DNS name, virtual IP, or load balancer address.

Then configure kubectl for your normal user:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

After `kubeadm init`, kubeadm also prints a `kubeadm join ...` command for worker nodes. Keep that command if you plan to join workers right away.

Example:
```bash
kubeadm join 192.168.2.2:6443 --token ivme4y.sap5k3hzhqnusd9j \
 --discovery-token-ca-cert-hash sha256:435a437746ac81b071ab631912a278c13e61e154b67fe6a861ba0b758ec6303c
```

Do not run `kubeadm init` or `k8s-init-cluster.sh` on a second control-plane node. Additional control-plane nodes must join the existing cluster, and this repo now expects the first control-plane bootstrap to always use a stable `controlPlaneEndpoint`.

# Install a CNI plugin

Without a CNI, nodes will stay NotReady.

For Calico, a common command is:

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml
```

Flannel:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Make sure the pod CIDR you used with kubeadm init matches the CNI you install. This CNI step is required after bootstrap.

## Remove taint - for 1 node cluster only

Taints:             node-role.kubernetes.io/control-plane:NoSchedule

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

## Join workers

Run the kubeadm join ... command printed by kubeadm init on each worker node, for example:

```bash
sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

You can reuse the same worker join command for multiple nodes as long as the token is still valid.



## Generate a fresh worker join command from the running cluster

Run this on an existing control-plane node:

```bash
sudo kubeadm token create --print-join-command
```

## Join an additional control-plane node

This only works if the first control-plane node was initialized with a stable `controlPlaneEndpoint`.

1. On the new control-plane node, run `k8s-prepare.sh` first.
2. On an existing control-plane node, upload the control-plane certificates and note the certificate key:

```bash
sudo kubeadm init phase upload-certs --upload-certs
```

3. On an existing control-plane node, create a fresh join command:

```bash
sudo kubeadm token create --print-join-command
```

4. On the new control-plane node, run that join command and add:

```bash
--control-plane --certificate-key <key>
```

Example:

```bash
sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --control-plane --certificate-key <KEY>
```

Do not run `k8s-init-cluster.sh` on additional control-plane nodes. That script is only for creating the cluster on the first control-plane node.

## If the cluster was created without `controlPlaneEndpoint`

If you see an error like:

```text
unable to add a new control plane instance to a cluster that doesn't have a stable controlPlaneEndpoint address
```

then the cluster was bootstrapped without a stable API endpoint.

The simplest recovery path is:

1. Reset the new node you tried to join:

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d /var/lib/cni /etc/kubernetes $HOME/.kube
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

2. If you want to recreate the cluster cleanly, reset the whole cluster.

Run this on every worker node and every additional control-plane node first:

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d /var/lib/cni /etc/kubernetes $HOME/.kube
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

Then run the same reset on the original first control-plane node:

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d /var/lib/cni /etc/kubernetes $HOME/.kube
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

3. Recreate the cluster from the first control-plane node with a stable endpoint:

```bash
CONTROL_PLANE_ENDPOINT=<stable endpoint>:6443 ./k8s-init-cluster.sh
```

Or with raw kubeadm:

```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --control-plane-endpoint <stable endpoint>:6443
```

4. Join worker and additional control-plane nodes again.

The reset commands above are destructive for that node's Kubernetes state. Do not run them on a healthy cluster unless you really intend to rebuild it.

More advanced options for later include putting the control plane behind a virtual IP or TCP load balancer. See the Kubernetes kubeadm HA guide:

https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/

Useful check:
```bash
sudo kubeadm token list
```

## Example deployments

This repo includes a couple of simple reusable manifests under `scripts/kubeadm/examples/`:

- `00-namespace.yaml` creates a `demo` namespace for the examples
- `busybox.yaml` creates a long-running BusyBox pod for troubleshooting
- `nginx.yaml` creates an NGINX `Deployment` and `Service`

Apply them from the repo root:

```bash
kubectl apply -f scripts/kubeadm/examples/00-namespace.yaml
kubectl apply -f scripts/kubeadm/examples/busybox.yaml
kubectl apply -f scripts/kubeadm/examples/nginx.yaml
```

Check that the workloads are up:

```bash
kubectl get all -n demo
```

Use BusyBox to test DNS and service-to-service connectivity inside the cluster:

```bash
kubectl exec -it -n demo busybox-demo -- nslookup nginx-demo
kubectl exec -it -n demo busybox-demo -- wget -qO- http://nginx-demo
```

Use port-forwarding to reach NGINX from your workstation:

```bash
kubectl port-forward -n demo svc/nginx-demo 8080:80
curl http://127.0.0.1:8080
```

If you only want a one-off shell in BusyBox instead of the reusable manifest:

```bash
kubectl run -it --rm debug --image=busybox:1.36 --restart=Never -- sh
```

Clean up the examples:

```bash
kubectl delete namespace demo
```

### Test running workloads

kubectl run -it busybox --image=busybox --restart=Never -- echo "hoj"

kubectl run nginx --image=nginx

