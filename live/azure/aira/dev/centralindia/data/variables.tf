variable "state_backend" {
  type        = object({ resource_group_name = string, storage_account_name = string, container_name = string })
  description = "Azure backend coordinates for dependency states; no credentials."
}
variable "key_vault_name" {
  type        = string
  description = "Globally unique Key Vault name."
}
variable "mysql_password" {
  type        = string
  sensitive   = true
  description = "Supply via TF_VAR_mysql_password from a secret manager."
}
