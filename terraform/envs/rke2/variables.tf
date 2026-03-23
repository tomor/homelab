variable "nodes" {
  description = "Map of RKE2 node definitions keyed by VM name. The disk attribute is currently ignored by the VirtualBox provider."
  type = map(object({
    cpus         = number
    memory       = string
    disk         = string
    ubuntu_image = string
    role         = optional(string)
  }))
}

variable "hostonly_interface" {
  description = "VirtualBox host-only adapter name used for SSH and cluster traffic."
  type        = string
  default     = "vboxnet0"
}

variable "virtualbox_image_path" {
  description = "Optional path to the pre-downloaded VirtualBox box/image artifact. Defaults to terraform/images/cloudicio-ubuntu-server-24.04.1-arm64.box."
  type        = string
  default     = null
  nullable    = true
}
