# Goal
Learning terraform, then kubernetest installation, first on my Macbook pro M3

## Plan
- My laptop has 36GB of RAM
- After picking the virtualisation tool for MacOS I wan to setup the terraform directory for provisioning one virtual machine (ubuntu) where I can later install k8s with kubeadm.

## Notes Multipass
- using "multipass" for virtualisation (AI recommended)
- If multipass shell fails with `shell failed: ssh connection failed: 'Failed to connect: No route to host'`
 > login directly with ssh:
 ```bash
sudo ssh -i '/var/root/Library/Application Support/multipassd/ssh-keys/id_rsa' ubuntu@192.168.2.17
 ```
 > next time try reboot, more info in https://github.com/canonical/multipass/issues/3766


# Progress tracking
[x] Basic terrraform setups for 1 local VM in multipass
[x] install kubernetes manually to one host
[] install kubernetes manually to multiple hosts (use join..)
[] test joining master nodes and worker nodes
[] test k8s upgrade, put some deployments there to see how they do


