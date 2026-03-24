output "vm_names" {
  description = "Names of the provisioned kubeadm VMs."
  value       = concat(keys(multipass_instance.cluster_nodes), keys(multipass_instance.load_balancer))
}

output "ipv4" {
  description = "IPv4 addresses of the provisioned kubeadm VMs."
  value = merge(
    { for name, instance in multipass_instance.cluster_nodes : name => instance.ipv4 },
    { for name, instance in multipass_instance.load_balancer : name => instance.ipv4 },
  )
}

output "load_balancer_ipv4" {
  description = "IPv4 address of the kubeadm HAProxy VM."
  value = one([
    for name, node in var.nodes : multipass_instance.load_balancer[name].ipv4
    if try(node.role, "") == "haproxy"
  ])
}

output "ansible_inventory" {
  description = "Structured host metadata for the Ansible dynamic inventory."
  value = {
    for name, node in var.nodes : name => {
      ansible_host = try(multipass_instance.cluster_nodes[name].ipv4, multipass_instance.load_balancer[name].ipv4)
      role         = replace(try(node.role, "ungrouped"), "-", "_")
      env          = "kubeadm"
    }
  }
}
