locals {
  settings = jsondecode(file(var.config_file))
  prefix   = "${local.settings.deployment_id}-${local.settings.environment}"
  config = merge(local.settings, {
    prefix              = local.prefix
    resource_group_name = try(local.settings.resource_group_name, "rg-${local.prefix}")
    mysql               = merge(local.settings.mysql, { name = try(local.settings.mysql.name, "${local.prefix}-mysql") })
    redis               = merge(local.settings.redis, { name = try(local.settings.redis.name, "${local.prefix}-cache") })
    machines            = { for key, machine in local.settings.machines : key => merge(machine, { name = try(machine.name, "${local.prefix}-${machine.suffix}") }) }
    tags = {
      product     = local.settings.product
      deployment  = local.settings.deployment_id
      environment = local.settings.environment
      managed_by  = "opentofu"
    }
  })
}
output "config" { value = local.config }
output "state_prefix" { value = "azure/${local.settings.deployment_id}/${local.settings.environment}/${local.settings.location}" }
