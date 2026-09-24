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
  description = "Subnet delegated to MySQL."
}
variable "vnet_id" {
  type        = string
  description = "VNet for private DNS."
}
variable "zone" {
  type        = string
  description = "Availability zone."
  default     = "1"
}
variable "sku" {
  type        = string
  description = "MySQL SKU."
  default     = "B_Standard_B1ms"
}
variable "mysql_version" {
  type        = string
  description = "Provider MySQL version identifier."
  default     = "8.0.21"
}
variable "storage_gb" {
  type        = number
  description = "Storage capacity in GB."
  default     = 20
}
variable "backup_retention_days" {
  type        = number
  description = "Point-in-time recovery retention."
  default     = 7
}
variable "admin_username" {
  type        = string
  description = "MySQL administrator."
  default     = "airaadmin"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Supply through TF_VAR_mysql_password from a secret manager; stored in protected state."
}
