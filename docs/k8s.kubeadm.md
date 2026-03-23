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

Run this once on the first control-plane node only:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

(That CIDR is commonly used with Calico. The exact --pod-network-cidr depends on the CNI plugin you choose. kubeadm installation and cluster creation are separate steps in the official docs.)

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

Do not run `kubeadm init` or `k8s-init-controlplane.sh` on a second control-plane node. Additional control-plane nodes must join the existing cluster.

# Install a CNI plugin

Without a CNI, nodes will stay NotReady.

For Calico, a common command is:

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml
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

## Test running workloads

kubectl run -it busybox --image=busybox --restart=Never -- echo "hoj"

kubectl run nginx --image=nginx


## Generate a fresh worker join command from the running cluster

Run this on an existing control-plane node:

```bash
sudo kubeadm token create --print-join-command
```

## Join an additional control-plane node

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

Do not run `k8s-init-controlplane.sh` on additional control-plane nodes. That script is only for creating the cluster on the first control-plane node.

Useful check:
```bash
sudo kubeadm token list
```
