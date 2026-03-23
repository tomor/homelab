output "vm_names" {
  description = "Names of the provisioned Multipass instances."
  value       = keys(multipass_instance.node)
}

output "ipv4" {
  description = "IPv4 addresses of the provisioned Multipass instances keyed by VM name."
  value = {
    for name, instance in multipass_instance.node :
    name => instance.ipv4
  }
}
