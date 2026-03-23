terraform {
  required_version = ">= 1.5.0"

  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

locals {
  scripts_dir    = abspath("${path.module}/../../../scripts/kubeadm")
  cloud_init_dir = abspath("${path.module}/../../modules/multipass-cluster/cloud-init")
}

resource "local_file" "kubeadm_cloud_init" {
  filename = "${local.cloud_init_dir}/.rendered/kubeadm.yaml"
  content = templatefile("${local.cloud_init_dir}/kubeadm.yaml.tftpl", {
    k8s_prepare_script_b64           = base64encode(file("${local.scripts_dir}/k8s-prepare.sh"))
    k8s_init_cluster_script_b64 = base64encode(file("${local.scripts_dir}/k8s-init-cluster.sh"))
  })
}

module "cluster" {
  source = "../../modules/multipass-cluster"

  depends_on = [local_file.kubeadm_cloud_init]

  nodes                   = var.nodes
  default_cloud_init_file = "${local.cloud_init_dir}/base.yaml"
  cloud_init_files = {
    control-plane = local_file.kubeadm_cloud_init.filename
    worker        = local_file.kubeadm_cloud_init.filename
  }
}
