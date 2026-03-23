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
  default     = "stable"
}

variable "rke2_cni" {
  description = "Default packaged CNI to use for the RKE2 server."
  type        = string
  default     = "canal"
}
