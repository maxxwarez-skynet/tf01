variable "resource_group_name" {
  type        = string
  description = "Dedicated backend resource group."
}
variable "storage_account_name" {
  type        = string
  description = "Globally unique lowercase state account name, 3-24 alphanumeric characters."
}
variable "location" {
  type        = string
  description = "Azure region."
  default     = "centralindia"
}
