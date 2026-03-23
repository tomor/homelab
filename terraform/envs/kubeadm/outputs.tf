output "vm_names" {
  description = "Names of the provisioned kubeadm VMs."
  value       = concat(module.cluster_nodes.vm_names, module.load_balancer.vm_names)
}

output "ipv4" {
  description = "IPv4 addresses of the provisioned kubeadm VMs."
  value       = merge(module.cluster_nodes.ipv4, module.load_balancer.ipv4)
}

output "load_balancer_ipv4" {
  description = "IPv4 address of the kubeadm HAProxy VM."
  value = one([
    for name, node in var.nodes : module.load_balancer.ipv4[name]
    if try(node.role, "") == "haproxy"
  ])
}
