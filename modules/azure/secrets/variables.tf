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
  description = "Private endpoint subnet ID."
}
variable "vnet_id" {
  type        = string
  description = "VNet for private DNS."
}
variable "tenant_id" {
  type        = string
  description = "Azure tenant ID."
}
