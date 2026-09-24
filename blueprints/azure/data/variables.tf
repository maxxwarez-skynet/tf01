variable "config" {
  type = object({
    location = string
    prefix   = string
    zone     = string
    mysql    = object({ name = string, sku = string, version = string, storage_gb = number, backup_retention_days = number, admin_username = string })
    redis    = object({ name = string, sku = string })
    tags     = map(string)
  })
  description = "Resolved deployment settings."
}
variable "foundation" {
  type        = object({ resource_group_name = string, vnet_id = string, subnet_ids = map(string) })
  description = "Foundation state outputs."
}
variable "key_vault_name" {
  type        = string
  description = "Globally unique vault name, 3-24 characters."
}

variable "mysql_password" {
  type        = string
  sensitive   = true
  description = "External secret supplied to the MySQL administrator."
}
