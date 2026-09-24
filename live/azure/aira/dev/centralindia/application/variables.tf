variable "state_backend" {
  type        = object({ resource_group_name = string, storage_account_name = string, container_name = string })
  description = "Azure backend coordinates for dependency states; no credentials."
}
variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key."
}
variable "admin_cidrs" {
  type        = set(string)
  description = "Administrative IPv4 CIDRs; empty disables SSH."
  default     = []
}
