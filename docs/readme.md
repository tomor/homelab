# Purpose

Kubernetes Experiments on an M3 MacBook Pro


## Basics

- My laptop has 36GB of RAM
- Use terraform for managing VMs.
- After picking the right virtualisation tool for MacOS I want to setup the terraform directory for provisioning one virtual machine (ubuntu) where I can later install k8s with kubeadm - later on creating more VMs an do more experimentation with HA k8s cluster.

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
[x] etcd backup, restore (RKE2)
[x] load balancer for HA kube-api
[x] ansible basic setup
[x] rke2 cluster setup via ansible
[] automated export of kubeconfig to workstation
[] verify k8s HA for CP nodes
[] service with ingress
[] API gateway
[] etcd backup, restore (kubeadm)
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

## Ansible

Ansible now provides a post-bootstrap way to push repo helper files that cloud-init originally copied only during VM creation.

Initial setup:

```bash
uv sync --project ansible
```

Provisioned VMs are expected to accept the dedicated SSH keypair `~/.ssh/homelab_vm` and `~/.ssh/homelab_vm.pub`. If you do not already have it, create it with:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/homelab_vm -C homelab-vm
```

That key is injected into new VMs by cloud-init. Existing VMs created before this change need to be recreated before direct SSH and Ansible will work.

Inspect the Terraform-backed inventory:

```bash
make ansible-inventory E=rke2
```

Push the current repo helper files into `/home/ubuntu/` on every non-HAProxy VM in the selected environment:

```bash
make ansible-push-files E=rke2
make ansible-push-files E=kubeadm
```

Bootstrap or reconcile the RKE2 cluster end-to-end with Ansible:

```bash
make ansible-rke2-cluster
```

Export the RKE2 kubeconfig to your workstation and update `/etc/hosts` for the API hostname:

```bash
make ansible-rke2-kubeconfig
```

This target prompts for your local sudo password before updating `/etc/hosts`.

Notes:

- The dynamic inventory reads `terraform output -json ansible_inventory` from `terraform/envs/<env>`.
- The selected Terraform environment is passed through `ANSIBLE_TF_ENV` and defaults to `rke2` if not set.
- Ansible connects as `ubuntu` and uses `~/.ssh/homelab_vm` by default.
- The base Ansible workflow still starts with file sync. Cluster automation is currently implemented only for RKE2.
- The first cluster automation target is RKE2. The RKE2 playbook wraps the existing helper scripts, prepares nodes, bootstraps the first server, reads the token, and joins the remaining nodes.
- The kubeconfig export target writes `~/.kube/homelab-rke2.yaml` and updates the local `/etc/hosts` entry for the current RKE2 API hostname.

## kubeadm notes

- For multi-control-plane kubeadm setup, the cluster must be created with a stable `controlPlaneEndpoint`.
- The kubeadm Terraform environment now provisions a dedicated HAProxy VM. After `make apply E=kubeadm`, read `terraform -chdir=terraform/envs/kubeadm output -raw load_balancer_ipv4`. Use that IP inside the cluster VMs for bootstrap and join commands. Map the same IP to `kubeadm-api.home.arpa` in your workstation `/etc/hosts` if you want hostname-based access there.
- Recovery steps, including commands to reset a failed joining node or rebuild the cluster, are documented in `docs/k8s.kubeadm.md`.
- Kubeadm VM bootstrap assets live under `scripts/kubeadm/`, including `.bash_aliases`, which is copied to `/home/ubuntu/.bash_aliases` by cloud-init.

## RKE2 notes

- The RKE2 Terraform environment now provisions a dedicated HAProxy VM. After `make apply E=rke2`, read `terraform -chdir=terraform/envs/rke2 output -raw load_balancer_ipv4`. Use that IP inside the cluster VMs for bootstrap and join commands. Map the same IP to `rke2-api.home.arpa` in your workstation `/etc/hosts` if you want hostname-based access there.
- RKE2 setup and operational notes are documented in `docs/k8s.rke2.md`.
- RKE2 VM bootstrap assets live under `scripts/rke2/`, including `.bash_aliases`, which is copied to `/home/ubuntu/.bash_aliases` by cloud-init.
- The Terraform environment in `terraform/envs/rke2/` now renders a cloud-init file that copies the RKE2 helper scripts and generated defaults onto each VM.


- How does k8s handle concurency for controllers, eg. deployment - which node does it do? -> only one is active - sync via "lease" -> kubectl get lease -n kube-system

## Terraforms notes

### Recreate one node

Recreate the RKE2 HA proxy VM:
```bash
terraform -chdir=terraform/envs/rke2 apply -replace='module.load_balancer.multipass_instance.node["rke2-lb-1"]'
```


## Usefull notes

### Can you do an etcd restore with zero workload disruption?
That is generally not the purpose of snapshot restore. Snapshot restore is mostly for disaster recovery, corruption, or “rewind the cluster to a known-good state.” It is not a live, zero-downtime repair mechanism for a healthy production control plane.

My experience from RKE2: Workloads kept first running at first, but after joining the 2nd and 3rd server node pods networking got corrupted and rke2-agent on the agent nodes as well as CNI (canal) had to be restarted.
