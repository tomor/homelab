variable "nodes" {
  description = "Map of kubeadm node definitions keyed by VM name."
  type = map(object({
    cpus         = number
    memory       = string
    disk         = string
    ubuntu_image = string
    role         = optional(string)
  }))
}
