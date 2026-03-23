output "vm_names" {
  description = "Names of the provisioned RKE2 VMs."
  value       = module.cluster.vm_names
}

output "ipv4" {
  description = "IPv4 addresses of the provisioned RKE2 VMs."
  value       = module.cluster.ipv4
}
