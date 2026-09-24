variable "config" {
  type = object({
    location       = string
    zone           = string
    admin_username = string
    image          = object({ publisher = string, offer = string, sku = string, version = string })
    machines       = map(object({ name = string, size = string, public_ports = set(number) }))
    tags           = map(string)
  })
  description = "VM definitions keyed by stable machine identifiers."
}
variable "foundation" {
  type        = object({ resource_group_name = string, subnet_ids = map(string) })
  description = "Foundation state outputs."
}
variable "key_vault_id" {
  type        = string
  description = "Vault granting VM identities read access."
}
variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key."
}
variable "admin_cidrs" {
  type        = set(string)
  description = "IPv4 administrative networks."
  default     = []
}
