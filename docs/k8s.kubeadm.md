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
```
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```


## Initialize the control plane

Run this on the control-plane node only:
```
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```
(That CIDR is commonly used with Calico. The exact --pod-network-cidr depends on the CNI plugin you choose. kubeadm installation and cluster creation are separate steps in the official docs.)

Then configure kubectl for your normal user:
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```


After kubeadm init, it will also print a kubeadm join ... command for worker nodes. Keep that command.

mine: 
kubeadm join 192.168.2.2:6443 --token ivme4y.sap5k3hzhqnusd9j \
	--discovery-token-ca-cert-hash sha256:435a437746ac81b071ab631912a278c13e61e154b67fe6a861ba0b758ec6303c


# Install a CNI plugin
Without a CNI, nodes will stay NotReady.

For Calico, a common command is:
```
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml
```
Make sure the pod CIDR you used with kubeadm init matches the CNI you install. This CNI step is required after bootstrap.


## Remove taint - for 1 node cluster only!
Taints:             node-role.kubernetes.io/control-plane:NoSchedule
```
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

## Join workers

Run the kubeadm join ... command printed by kubeadm init on each worker node, for example:

```
sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```


## Test running workloads


kubectl run -it busybox --image=busybox --restart=Never -- echo "hoj"

kubectl run nginx --image=nginx