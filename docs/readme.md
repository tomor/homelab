# Goal

Learning terraform, then kubernetest installation, first on my Macbook pro M3

## tmp
``` bash
worker:
sudo kubeadm join 192.168.2.22:6443 --token axxcj0.mdp8vpgfyzzk23u1 --discovery-token-ca-cert-hash sha256:3b31c71dae4e176ade612aef1ff2bb178364986f5569e134e9bf885daaab9123

cp node:
sudo kubeadm join 192.168.2.22:6443 --token axxcj0.mdp8vpgfyzzk23u1 --discovery-token-ca-cert-hash sha256:3b31c71dae4e176ade612aef1ff2bb178364986f5569e134e9bf885daaab9123 --control-plane --certificate-key <key>
```


## Plan

- My laptop has 36GB of RAM
- After picking the virtualisation tool for MacOS I wan to setup the terraform directory for provisioning one virtual machine (ubuntu) where I can later install k8s with kubeadm.

## Notes

- Using "multipass" for virtualisation.
- I've tested VirtualBox, because of issues I had, but returned to multipass.
- I came back to multipass and found out the issue was not multipass, but Calico intalling wrong route on the VM which made the VM appear "dead" - it was unreachable. VM stop/start recovered the issue because the route was not permanent.
  ```
  192.168.2.1 via 192.168.2.25 dev tunl0 proto bird onlink
  ``` 
- I've switched to Flannel which works fine (kubeadm installed k8s)


## Progress tracking

[x] basic terrraform setups for 1 local VM in multipass
[x] install kubernetes manually to one host
[x] test VirtualBox 
[x] test joining multiple worker nodes
[x] test joining master nodes
[x] test k8s upgrade, put some deployments there to see how they do
[x] host os upgrade with restart
[x] install RKE2 cluster
[x] rke2 upgrade
[] load balancer / ingress
[] API gateway
[] etcd backup, restore
[] storage


## Multipass troubleshooting

- If multipass shell fails with `shell failed: ssh connection failed: 'Failed to connect: No route to host'`
- Try restarting the VM, the issue I had was not caused by multipass, but by calico installing wrong routes. They were not permanent and after VM restart the VM was accessible for a while - till calico broke the routing.

- If two Multipass VMs come up with the same IP and `multipass shell` fails with `ssh connection failed: 'Connection refused'`, delete and recreate them. The root `make apply` wrapper now runs with `-parallelism=1` to avoid this duplicate-DHCP race on macOS.

## VM lifecycle

From the repo root, you can start or stop the full VM group for one environment:

```bash
make start E=rke2
make stop E=rke2
```

- `E` selects the Terraform environment, for example `kubeadm` or `rke2`.
- The Make targets resolve VM membership from the environment's Terraform output `vm_names`, so the environment must already exist (`make apply E=...`).
- This is useful when a Multipass VM needs a clean restart without recreating the whole environment.

## kubeadm notes

- For multi-control-plane kubeadm setup, the cluster must be created with a stable `controlPlaneEndpoint`.
- Recovery steps, including commands to reset a failed joining node or rebuild the cluster, are documented in `docs/k8s.kubeadm.md`.
- Kubeadm VM bootstrap assets live under `scripts/kubeadm/`, including `.bash_aliases`, which is copied to `/home/ubuntu/.bash_aliases` by cloud-init.

## RKE2 notes

- The first RKE2 workflow in this repo targets a single `server` node with one or more `agent` nodes.
- RKE2 setup and operational notes are documented in `docs/k8s.rke2.md`.
- RKE2 VM bootstrap assets live under `scripts/rke2/`, including `.bash_aliases`, which is copied to `/home/ubuntu/.bash_aliases` by cloud-init.
- The Terraform environment in `terraform/envs/rke2/` now renders a cloud-init file that copies the RKE2 helper scripts and generated defaults onto each VM.


- How does k8s handle concurency for controllers, eg. deployment - which node does it do? -> only one is active - sync via "lease" -> kubectl get lease -n kube-system

## Terraforms notes

### Recreate one node

```bash
terraform apply -replace='module.cluster.multipass_instance.node["kubeadm-cp-1"]'
```
