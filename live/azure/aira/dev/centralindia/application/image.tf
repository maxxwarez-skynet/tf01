variable "ubuntu_image_version" {
  type        = string
  description = "Exact Ubuntu Marketplace image version; use az vm image list to select one."
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.ubuntu_image_version))
    error_message = "Supply a pinned numeric Marketplace image version, not latest."
  }
}
