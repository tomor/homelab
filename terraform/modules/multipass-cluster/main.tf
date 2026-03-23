locals {
  nodes = var.nodes
}

resource "multipass_instance" "node" {
  for_each = local.nodes

  name   = each.key
  image  = each.value.ubuntu_image
  cpus   = each.value.cpus
  memory = each.value.memory
  disk   = each.value.disk

  cloudinit_file = lookup(var.cloud_init_files, coalesce(each.value.role, "default"), var.default_cloud_init_file)
}
