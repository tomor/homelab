output "vm_name" {
  description = "Name of the provisioned Multipass instance."
  value       = multipass_instance.node.name
}

output "ipv4" {
  description = "IPv4 address of the provisioned Multipass instance."
  value       = multipass_instance.node.ipv4
}
