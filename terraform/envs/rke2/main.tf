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
  virtualbox_image_path = var.virtualbox_image_path != null ? abspath(pathexpand(var.virtualbox_image_path)) : abspath("${path.module}/../../images/cloudicio-ubuntu-server-24.04.1-arm64.box")
}

module "cluster" {
  source = "../../modules/virtualbox-cluster"

  image_path         = local.virtualbox_image_path
  nodes              = var.nodes
  hostonly_interface = var.hostonly_interface
}
