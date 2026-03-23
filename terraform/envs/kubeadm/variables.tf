variable "nodes" {
  description = "Map of kubeadm node definitions keyed by VM name. The disk attribute is currently ignored by the VirtualBox provider."
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

variable "bootstrap_ssh_user" {
  description = "Bootstrap SSH user used for post-create provisioning. For the current ARM64 VirtualBox box this is typically `vagrant`."
  type        = string
  default     = "vagrant"
}

variable "bootstrap_ssh_private_key_path" {
  description = "Optional bootstrap SSH private key used for post-create provisioning. If unset, Terraform will create the VMs but will not copy kubeadm helper scripts automatically."
  type        = string
  default     = null
  nullable    = true
}

variable "managed_ssh_public_key_path" {
  description = "Optional public key to install into the VM for long-term access after bootstrap. Recommended for day-to-day login."
  type        = string
  default     = null
  nullable    = true
}
