terraform {
  required_version = ">= 1.5.0"

  required_providers {
    virtualbox = {
      source  = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

locals {
  scripts_dir             = abspath("${path.module}/../../../scripts/kubeadm")
  bootstrap_enabled       = var.bootstrap_ssh_private_key_path != null
  managed_ssh_key_enabled = local.bootstrap_enabled && var.managed_ssh_public_key_path != null
  virtualbox_image_path   = var.virtualbox_image_path != null ? abspath(pathexpand(var.virtualbox_image_path)) : abspath("${path.module}/../../images/cloudicio-ubuntu-server-24.04.1-arm64.box")
}

module "cluster" {
  source = "../../modules/virtualbox-cluster"

  image_path         = local.virtualbox_image_path
  nodes              = var.nodes
  hostonly_interface = var.hostonly_interface
}

resource "terraform_data" "kubeadm_assets" {
  for_each = local.bootstrap_enabled ? var.nodes : {}

  depends_on = [module.cluster]

  triggers_replace = {
    host               = module.cluster.ipv4[each.key]
    ssh_user           = var.bootstrap_ssh_user
    ssh_private_key    = var.bootstrap_ssh_private_key_path
    prepare_script_sha = filebase64sha256("${local.scripts_dir}/k8s-prepare.sh")
    init_script_sha    = filebase64sha256("${local.scripts_dir}/k8s-init-cluster.sh")
    aliases_sha        = filebase64sha256("${local.scripts_dir}/.bash_aliases")
  }

  connection {
    type        = "ssh"
    user        = var.bootstrap_ssh_user
    host        = module.cluster.ipv4[each.key]
    private_key = file(pathexpand(var.bootstrap_ssh_private_key_path))
  }

  provisioner "file" {
    source      = "${local.scripts_dir}/k8s-prepare.sh"
    destination = "/tmp/k8s-prepare.sh"
  }

  provisioner "file" {
    source      = "${local.scripts_dir}/k8s-init-cluster.sh"
    destination = "/tmp/k8s-init-cluster.sh"
  }

  provisioner "file" {
    source      = "${local.scripts_dir}/.bash_aliases"
    destination = "/tmp/.bash_aliases"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0755 /tmp/k8s-prepare.sh /tmp/k8s-init-cluster.sh",
      "install -m 0755 /tmp/k8s-prepare.sh /home/${var.bootstrap_ssh_user}/k8s-prepare.sh",
      "install -m 0755 /tmp/k8s-init-cluster.sh /home/${var.bootstrap_ssh_user}/k8s-init-cluster.sh",
      "install -m 0644 /tmp/.bash_aliases /home/${var.bootstrap_ssh_user}/.bash_aliases",
      "sudo chown ${var.bootstrap_ssh_user}:${var.bootstrap_ssh_user} /home/${var.bootstrap_ssh_user}/k8s-prepare.sh /home/${var.bootstrap_ssh_user}/k8s-init-cluster.sh /home/${var.bootstrap_ssh_user}/.bash_aliases",
    ]
  }
}

resource "terraform_data" "managed_ssh_key" {
  for_each = local.managed_ssh_key_enabled ? var.nodes : {}

  depends_on = [terraform_data.kubeadm_assets]

  triggers_replace = {
    host            = module.cluster.ipv4[each.key]
    ssh_user        = var.bootstrap_ssh_user
    ssh_private_key = var.bootstrap_ssh_private_key_path
    managed_key_sha = filebase64sha256(pathexpand(var.managed_ssh_public_key_path))
  }

  connection {
    type        = "ssh"
    user        = var.bootstrap_ssh_user
    host        = module.cluster.ipv4[each.key]
    private_key = file(pathexpand(var.bootstrap_ssh_private_key_path))
  }

  provisioner "file" {
    source      = pathexpand(var.managed_ssh_public_key_path)
    destination = "/tmp/homelab-managed.pub"
  }

  provisioner "remote-exec" {
    inline = [
      "install -d -m 0700 /home/${var.bootstrap_ssh_user}/.ssh",
      "touch /home/${var.bootstrap_ssh_user}/.ssh/authorized_keys",
      "grep -qxF \"$(cat /tmp/homelab-managed.pub)\" /home/${var.bootstrap_ssh_user}/.ssh/authorized_keys || cat /tmp/homelab-managed.pub >> /home/${var.bootstrap_ssh_user}/.ssh/authorized_keys",
      "chmod 0600 /home/${var.bootstrap_ssh_user}/.ssh/authorized_keys",
      "sudo chown -R ${var.bootstrap_ssh_user}:${var.bootstrap_ssh_user} /home/${var.bootstrap_ssh_user}/.ssh",
    ]
  }
}
