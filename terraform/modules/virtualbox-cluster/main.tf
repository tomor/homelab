terraform {
  required_providers {
    virtualbox = {
      source  = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

resource "virtualbox_vm" "node" {
  for_each = var.nodes

  name   = each.key
  image  = var.image_path
  cpus   = each.value.cpus
  memory = each.value.memory
  status = var.vm_status

  dynamic "network_adapter" {
    for_each = var.enable_nat_adapter ? [1] : []

    content {
      type = "nat"
    }
  }

  network_adapter {
    type           = "hostonly"
    host_interface = var.hostonly_interface
  }
}
