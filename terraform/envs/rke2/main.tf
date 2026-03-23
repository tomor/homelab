terraform {
  required_version = ">= 1.5.0"

  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4"
    }
  }
}

module "cluster" {
  source = "../../modules/multipass-cluster"

  nodes                   = var.nodes
  default_cloud_init_file = "${path.module}/../../modules/multipass-cluster/cloud-init/base.yaml"
  cloud_init_files = {
    server = "${path.module}/../../modules/multipass-cluster/cloud-init/rke2.yaml"
    agent  = "${path.module}/../../modules/multipass-cluster/cloud-init/rke2.yaml"
  }
}
