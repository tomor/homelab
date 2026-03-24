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

variable "ssh_authorized_key" {
  description = "SSH public key installed for the ubuntu user on provisioned VMs."
  type        = string
  default     = null
  nullable    = true
}
