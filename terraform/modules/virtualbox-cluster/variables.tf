variable "nodes" {
  description = "Map of VirtualBox VM definitions keyed by VM name. The disk and ubuntu_image attributes are retained for compatibility but are currently ignored because all VMs reuse one local image artifact and the provider does not expose primary disk sizing."
  type = map(object({
    cpus         = number
    memory       = string
    disk         = string
    ubuntu_image = string
    role         = optional(string)
  }))
}

variable "image_path" {
  description = "Absolute path to the pre-downloaded VirtualBox image or box artifact reused by all VMs."
  type        = string
}

variable "hostonly_interface" {
  description = "VirtualBox host-only adapter name used for host-to-guest SSH and cluster traffic."
  type        = string
  default     = "vboxnet0"
}

variable "enable_nat_adapter" {
  description = "Whether to attach a NAT adapter before the host-only adapter so guests keep outbound internet access."
  type        = bool
  default     = true
}

variable "vm_status" {
  description = "Desired runtime status for provisioned VMs."
  type        = string
  default     = "running"

  validation {
    condition     = contains(["running", "poweroff"], var.vm_status)
    error_message = "vm_status must be either \"running\" or \"poweroff\"."
  }
}
