nodes = {
  "kubeadm-cp-1" = {
    cpus         = 2
    memory       = "4G"
    disk         = "20G"
    ubuntu_image = "24.04"
    role         = "control-plane"
  }
  "kubeadm-cp-2" = {
    cpus         = 2
    memory       = "4G"
    disk         = "20G"
    ubuntu_image = "24.04"
    role         = "control-plane"
  }
  "kubeadm-cp-3" = {
    cpus         = 2
    memory       = "4G"
    disk         = "20G"
    ubuntu_image = "24.04"
    role         = "control-plane"
  }
  "kubeadm-worker-1" = {
    cpus         = 2
    memory       = "4G"
    disk         = "20G"
    ubuntu_image = "24.04"
    role         = "worker"
  }
  "kubeadm-worker-2" = {
    cpus         = 2
    memory       = "4G"
    disk         = "20G"
    ubuntu_image = "24.04"
    role         = "worker"
  }
  "kubeadm-lb-1" = {
    cpus         = 1
    memory       = "1G"
    disk         = "10G"
    ubuntu_image = "24.04"
    role         = "haproxy"
  }
}
