variable "vm_name" {
  type        = string
  description = "Name of the Multipass VM instance."
  default     = "k8s-node"
}

variable "cpus" {
  type        = number
  description = "Number of vCPUs to allocate to the VM."
  default     = 2
}

variable "memory" {
  type        = string
  description = "Amount of memory to allocate (e.g. '4G')."
  default     = "4G"
}

variable "disk" {
  type        = string
  description = "Disk size to allocate (e.g. '20G')."
  default     = "20G"
}

variable "ubuntu_image" {
  type        = string
  description = "Ubuntu release to use as the VM image (e.g. '24.04')."
  default     = "24.04"
}
