variable "name" {
  type        = string
  description = "Resource name or prefix."
}
variable "resource_group_name" {
  type        = string
  description = "Owning resource group."
}
variable "location" {
  type        = string
  description = "Azure region."
}
variable "tags" {
  type        = map(string)
  description = "Resource tags."
  default     = {}
}
variable "subnet_id" {
  type        = string
  description = "Web subnet ID."
}
variable "size" {
  type        = string
  description = "Azure VM size."
  default     = "Standard_B2ms"
}
variable "zone" {
  type        = string
  description = "Availability zone."
  default     = "1"
}
variable "admin_username" {
  type        = string
  description = "SSH administrator."
  default     = "airaadmin"
}
variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key; private keys must never be passed."
}

variable "admin_cidrs" {
  type        = set(string)
  description = "IPv4 administrative CIDRs for SSH; empty disables SSH ingress."
  default     = []
  validation {
    condition     = alltrue([for cidr in var.admin_cidrs : can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) >= 8, false)])
    error_message = "Use explicit IPv4 administrative CIDRs with prefix /8 or narrower; internet-wide SSH is prohibited."
  }
}
variable "public_ports" {
  type        = set(number)
  description = "Public TCP application ports. SSH is managed separately."
  default     = [80, 443]
  validation {
    condition     = alltrue([for port in var.public_ports : port >= 1 && port <= 65535 && floor(port) == port && port != 22])
    error_message = "Public ports must be integers between 1 and 65535 excluding SSH (22)."
  }
}
variable "image" {
  type        = object({ publisher = string, offer = string, sku = string, version = string })
  description = "Pinned Ubuntu Marketplace image."
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image.version))
    error_message = "Supply a pinned numeric Marketplace image version, not latest."
  }
}
