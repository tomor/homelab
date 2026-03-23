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

variable "api_hostname" {
  description = "Stable DNS hostname used for the kubeadm API load balancer."
  type        = string
}
