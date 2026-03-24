variable "nodes" {
  description = "Map of RKE2 node definitions keyed by VM name."
  type = map(object({
    cpus         = number
    memory       = string
    disk         = string
    ubuntu_image = string
    role         = optional(string)
  }))
}

variable "rke2_channel" {
  description = "RKE2 release channel used by the helper scripts."
  type        = string
}

variable "rke2_cni" {
  description = "Default packaged CNI to use for the RKE2 server."
  type        = string
}

variable "api_hostname" {
  description = "Stable DNS hostname used for the RKE2 API and registration load balancer."
  type        = string
}

variable "ssh_authorized_key" {
  description = "SSH public key installed for the ubuntu user on provisioned VMs."
  type        = string
  default     = null
  nullable    = true
}
