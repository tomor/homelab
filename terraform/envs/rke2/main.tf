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
  cloud_init_dir = abspath("${path.module}/cloud-init")
  cluster_nodes = {
    for name, node in var.nodes : name => node
    if try(node.role, "") != "haproxy"
  }
  server_nodes = {
    for name, node in var.nodes : name => node
    if try(node.role, "") == "server"
  }
  agent_nodes = {
    for name, node in var.nodes : name => node
    if try(node.role, "") == "agent"
  }
  haproxy_nodes = {
    for name, node in var.nodes : name => node
    if try(node.role, "") == "haproxy"
  }
}

resource "local_file" "rke2_cloud_init" {
  filename = "${local.cloud_init_dir}/.rendered/rke2.yaml"
  content = templatefile("${local.cloud_init_dir}/rke2.yaml.tftpl", {
    rke2_prepare_script_b64       = base64encode(file("${local.scripts_dir}/rke2-prepare.sh"))
    rke2_init_server_script_b64   = base64encode(file("${local.scripts_dir}/rke2-init-server.sh"))
    rke2_join_server_script_b64   = base64encode(file("${local.scripts_dir}/rke2-join-server.sh"))
    rke2_join_agent_script_b64    = base64encode(file("${local.scripts_dir}/rke2-join-agent.sh"))
    bash_aliases_b64              = base64encode(file("${local.scripts_dir}/.bash_aliases"))
    rke2_ingress_nginx_config_b64 = base64encode(file("${local.scripts_dir}/rke2-ingress-nginx-config.yaml"))
    rke2_env_b64 = base64encode(<<-EOT
      # Generated from terraform/envs/rke2
      export INSTALL_RKE2_CHANNEL="${var.rke2_channel}"
      export RKE2_CNI="${var.rke2_cni}"
      export RKE2_API_HOSTNAME="${var.api_hostname}"
      EOT
    )
  })
}

resource "local_file" "haproxy_cloud_init" {
  filename = "${local.cloud_init_dir}/.rendered/rke2-haproxy.yaml"
  content = templatefile("${local.cloud_init_dir}/haproxy.yaml.tftpl", {
    cluster_name          = "rke2"
    api_backends          = [for name in keys(local.server_nodes) : { name = name, address = multipass_instance.cluster_nodes[name].ipv4 }]
    http_backends         = [for name in keys(local.agent_nodes) : { name = name, address = multipass_instance.cluster_nodes[name].ipv4 }]
    registration_backends = [for name in keys(local.server_nodes) : { name = name, address = multipass_instance.cluster_nodes[name].ipv4 }]
  })
}

resource "multipass_instance" "cluster_nodes" {
  depends_on = [local_file.rke2_cloud_init]

  for_each = local.cluster_nodes

  name   = each.key
  image  = each.value.ubuntu_image
  cpus   = each.value.cpus
  memory = each.value.memory
  disk   = each.value.disk

  cloudinit_file = lookup({
    server = local_file.rke2_cloud_init.filename
    agent  = local_file.rke2_cloud_init.filename
  }, try(each.value.role, ""), "${local.cloud_init_dir}/base.yaml")
}

resource "multipass_instance" "load_balancer" {
  depends_on = [local_file.haproxy_cloud_init]

  for_each = local.haproxy_nodes

  name   = each.key
  image  = each.value.ubuntu_image
  cpus   = each.value.cpus
  memory = each.value.memory
  disk   = each.value.disk

  cloudinit_file = local_file.haproxy_cloud_init.filename
}
