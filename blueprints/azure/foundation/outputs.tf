output "resource_group_name" { value = azurerm_resource_group.this.name }
output "vnet_id" { value = module.network.id }
output "subnet_ids" { value = module.network.subnet_ids }
