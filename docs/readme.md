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
- I've tested VirtualBox, because of issues with multipass, but I wasn't even able to start a working VM.
- I came back to multipass and found out the issue was not multipass, but Calico intalling wrong route on the VM which made the VM appear "dead" - it was unreachable. VM stop/start recovered the issue because the route was not permanent.
  ```
  192.168.2.1 via 192.168.2.25 dev tunl0 proto bird onlink
  ``` 
- I'm testing Flannel now.


## Progress tracking

[x] Basic terrraform setups for 1 local VM in multipass
[x] install kubernetes manually to one host
[x] Test VirtualBox
[x] test joining multiple worker nodes
[x] test joining master nodes
[x] test k8s upgrade, put some deployments there to see how they do
[x] host os upgrade with restart
[] etcd backup, restore


## Multipass troubleshooting

- If multipass shell fails with `shell failed: ssh connection failed: 'Failed to connect: No route to host'`

 > restart computer
 or
 > login directly with ssh

 ```bash
sudo ssh -i '/var/root/Library/Application Support/multipassd/ssh-keys/id_rsa' ubuntu@192.168.2.17
 ```

 > next time try reboot, more info in <https://github.com/canonical/multipass/issues/3766>

## kubeadm notes

- For multi-control-plane kubeadm setup, the cluster must be created with a stable `controlPlaneEndpoint`.
- Recovery steps, including commands to reset a failed joining node or rebuild the cluster, are documented in `docs/k8s.kubeadm.md`.
- Kubeadm VM bootstrap assets live under `scripts/kubeadm/`, including `.bash_aliases`, which is copied to `/home/ubuntu/.bash_aliases` by cloud-init.


- How does k8s handle concurency for controllers, eg. deployment - which node does it do? -> only one is active - sync via "lease" -> kubectl get lease -n kube-system

## Terraforms notes

### Recreate one node

```bash
terraform apply -replace='module.cluster.multipass_instance.node["kubeadm-cp-1"]'
```