output "vm_names" {
  description = "Names of the provisioned RKE2 VMs."
  value       = concat(keys(multipass_instance.cluster_nodes), keys(multipass_instance.load_balancer))
}

output "ipv4" {
  description = "IPv4 addresses of the provisioned RKE2 VMs."
  value = merge(
    { for name, instance in multipass_instance.cluster_nodes : name => instance.ipv4 },
    { for name, instance in multipass_instance.load_balancer : name => instance.ipv4 },
  )
}

output "load_balancer_ipv4" {
  description = "IPv4 address of the RKE2 HAProxy VM."
  value = one([
    for name, node in var.nodes : multipass_instance.load_balancer[name].ipv4
    if try(node.role, "") == "haproxy"
  ])
}
