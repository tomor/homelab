locals {
  hostonly_adapter_index = var.enable_nat_adapter ? 1 : 0
}

output "vm_names" {
  description = "Names of the provisioned VirtualBox instances."
  value       = keys(virtualbox_vm.node)
}

output "ipv4" {
  description = "IPv4 addresses of the provisioned VirtualBox instances keyed by VM name."
  value = {
    for name, instance in virtualbox_vm.node :
    name => try(instance.network_adapter[local.hostonly_adapter_index].ipv4_address, null)
  }
}
