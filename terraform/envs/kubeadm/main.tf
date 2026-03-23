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
  cluster_nodes = {
    for name, node in var.nodes : name => node
    if try(node.role, "") != "haproxy"
  }
  control_plane_nodes = {
    for name, node in var.nodes : name => node
    if try(node.role, "") == "control-plane"
  }
  haproxy_nodes = {
    for name, node in var.nodes : name => node
    if try(node.role, "") == "haproxy"
  }
}

resource "local_file" "kubeadm_cloud_init" {
  filename = "${local.cloud_init_dir}/.rendered/kubeadm.yaml"
  content = templatefile("${local.cloud_init_dir}/kubeadm.yaml.tftpl", {
    k8s_prepare_script_b64      = base64encode(file("${local.scripts_dir}/k8s-prepare.sh"))
    k8s_init_cluster_script_b64 = base64encode(file("${local.scripts_dir}/k8s-init-cluster.sh"))
    bash_aliases_b64            = base64encode(file("${local.scripts_dir}/.bash_aliases"))
  })
}

resource "local_file" "haproxy_cloud_init" {
  filename = "${local.cloud_init_dir}/.rendered/kubeadm-haproxy.yaml"
  content = templatefile("${local.cloud_init_dir}/haproxy.yaml.tftpl", {
    cluster_name          = "kubeadm"
    api_backends          = [for name in keys(local.control_plane_nodes) : { name = name, address = module.cluster_nodes.ipv4[name] }]
    registration_backends = null
  })
}

module "cluster_nodes" {
  source = "../../modules/multipass-cluster"

  depends_on = [local_file.kubeadm_cloud_init]

  nodes                   = local.cluster_nodes
  default_cloud_init_file = "${local.cloud_init_dir}/base.yaml"
  cloud_init_files = {
    control-plane = local_file.kubeadm_cloud_init.filename
    worker        = local_file.kubeadm_cloud_init.filename
  }
}

module "load_balancer" {
  source = "../../modules/multipass-cluster"

  depends_on = [local_file.haproxy_cloud_init]

  nodes                   = local.haproxy_nodes
  default_cloud_init_file = local_file.haproxy_cloud_init.filename
  cloud_init_files = {
    haproxy = local_file.haproxy_cloud_init.filename
  }
}
