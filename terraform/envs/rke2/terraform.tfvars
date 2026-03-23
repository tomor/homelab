rke2_channel = "stable"
rke2_cni     = "canal"

nodes = {
  "rke2-server-1" = {
    cpus         = 2
    memory       = "4G"
    disk         = "20G"
    ubuntu_image = "24.04"
    role         = "server"
  }
  "rke2-agent-1" = {
    cpus         = 2
    memory       = "4G"
    disk         = "20G"
    ubuntu_image = "24.04"
    role         = "agent"
  }
}
