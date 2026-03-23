resource "multipass_instance" "node" {
  name   = var.vm_name
  image  = var.ubuntu_image
  cpus   = var.cpus
  memory = var.memory
  disk   = var.disk

  cloudinit_file = "${path.module}/cloud-init.yaml"
}
