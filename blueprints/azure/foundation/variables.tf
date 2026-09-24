variable "config" {
  type = object({
    resource_group_name = string
    location            = string
    prefix              = string
    address_space       = list(string)
    subnets             = map(string)
    tags                = map(string)
  })
  description = "Resolved deployment configuration."
}
