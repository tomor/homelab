variable "nodes" {
  description = "Map of Multipass VM definitions keyed by VM name."
  type = map(object({
    cpus         = number
    memory       = string
    disk         = string
    ubuntu_image = string
    role         = optional(string)
  }))
}

variable "default_cloud_init_file" {
  description = "Fallback cloud-init file path used when no role-specific file is defined."
  type        = string
}

variable "cloud_init_files" {
  description = "Optional cloud-init file paths keyed by node role."
  type        = map(string)
  default     = {}
}
