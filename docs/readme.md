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
- I've tested multipass for virtualization on macOS M3, but it was not working well. I had issues with stuck VMs, not possible to shell into it.
- I've tested VirtualBox and I was not even able to start a VM properly



- I'm not testing using VirtualBox for virtualization on macOS Apple Silicon
- `terraform/modules/virtualbox-cluster` resolves `ubuntu_image = "24.04"` to a tested ARM64 VirtualBox box URL (`cloudicio/ubuntu-server` 24.04.1)
- the current Terraform VirtualBox provider does not expose primary disk resizing, so the `disk` values in tfvars are kept for intent but are not enforced yet

## Progress tracking

[x] Basic terrraform setup for local VM in multipass
[x] install kubernetes manually to one host
[x] test joining multiple worker nodes
[x] switch terraform setup to use VirtualBox
[] test joining master nodes
[] test k8s upgrade, put some deployments there to see how they do

## VirtualBox notes

- Install the Apple Silicon build of VirtualBox 7.1+ and make sure the `vboxnet0` host-only adapter exists before running Terraform.
- Recommended SSH model:
  - create one long-term key pair for these VMs, for example `ssh-keygen -t ed25519 -f ~/.ssh/homelab_vm`
  - set `managed_ssh_public_key_path` to `~/.ssh/homelab_vm.pub` so Terraform installs that key into `/home/vagrant/.ssh/authorized_keys`
  - `bootstrap_ssh_private_key_path` is only for first-boot provisioning; if you have the standard Vagrant insecure key locally, point it there
- VM login after your key is installed should use your managed key:

```bash
ssh -i ~/.ssh/homelab_vm vagrant@<vm-ip>
```

- If `bootstrap_ssh_private_key_path` is not set, Terraform still creates the VMs but skips the post-create SSH provisioning step.
- Kubeadm helper assets from `scripts/kubeadm/` are copied into `/home/vagrant/` by Terraform over SSH after VM creation when bootstrap SSH is configured.


### Download the local VirtualBox image once

Store one pinned box artifact locally and let every VM reuse that same file.

1. Open the registry page:

   `https://portal.cloud.hashicorp.com/vagrant/discover/cloudicio/ubuntu-server`

2. Download the `24.04.1` `VirtualBox` `arm64` box manually from that page.

3. Save it as:

   `terraform/images/cloudicio-ubuntu-server-24.04.1-arm64.box`

Create the target directory first if needed:

By default both Terraform environments look for:

```text
terraform/images/cloudicio-ubuntu-server-24.04.1-arm64.box
```

If you store the file somewhere else, set `virtualbox_image_path` in the environment:

```hcl
virtualbox_image_path = "~/Downloads/cloudicio-ubuntu-server-24.04.1-arm64.box"
```

## Terraforms notes

### Recreate one node
multipass
```bash
terraform apply -replace='module.cluster.multipass_instance.node["kubeadm-cp-1"]'
```

virtualbox
```bash
terraform apply -replace='module.cluster.virtualbox_vm.node["kubeadm-cp-1"]'
```

