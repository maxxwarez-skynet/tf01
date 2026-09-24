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
variable "address_space" {
  type        = list(string)
  description = "VNet IPv4 CIDRs."
}
variable "subnets" {
  type        = map(string)
  description = "IPv4 CIDRs keyed by web, data, cache; ensure ranges are disjoint and inside the VNet."
  validation {
    condition     = alltrue([for name in ["web", "data", "cache"] : contains(keys(var.subnets), name)]) && alltrue([for cidr in values(var.subnets) : can(cidrnetmask(cidr))])
    error_message = "Provide valid IPv4 CIDRs for web, data, and cache."
  }
}
