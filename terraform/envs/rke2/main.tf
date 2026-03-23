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
  scripts_dir    = abspath("${path.module}/../../../scripts/rke2")
  cloud_init_dir = abspath("${path.module}/../../modules/multipass-cluster/cloud-init")
}

resource "local_file" "rke2_cloud_init" {
  filename = "${local.cloud_init_dir}/.rendered/rke2.yaml"
  content = templatefile("${local.cloud_init_dir}/rke2.yaml.tftpl", {
    rke2_prepare_script_b64     = base64encode(file("${local.scripts_dir}/rke2-prepare.sh"))
    rke2_init_server_script_b64 = base64encode(file("${local.scripts_dir}/rke2-init-server.sh"))
    rke2_join_server_script_b64 = base64encode(file("${local.scripts_dir}/rke2-join-server.sh"))
    rke2_join_agent_script_b64  = base64encode(file("${local.scripts_dir}/rke2-join-agent.sh"))
    bash_aliases_b64            = base64encode(file("${local.scripts_dir}/.bash_aliases"))
    rke2_env_b64 = base64encode(<<-EOT
      # Generated from terraform/envs/rke2
      export INSTALL_RKE2_CHANNEL="${var.rke2_channel}"
      export RKE2_CNI="${var.rke2_cni}"
      EOT
    )
  })
}

module "cluster" {
  source = "../../modules/multipass-cluster"

  depends_on = [local_file.rke2_cloud_init]

  nodes                   = var.nodes
  default_cloud_init_file = "${local.cloud_init_dir}/base.yaml"
  cloud_init_files = {
    server = local_file.rke2_cloud_init.filename
    agent  = local_file.rke2_cloud_init.filename
  }
}
