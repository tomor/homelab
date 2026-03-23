# Terraforms notes

### Recreated one node

```bash
terraform apply -replace='module.cluster.multipass_instance.node["kubeadm-cp-1"]'
```
