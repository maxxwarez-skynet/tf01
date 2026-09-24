output "id" { value = azurerm_virtual_network.this.id }
output "subnet_ids" { value = { for key, subnet in azurerm_subnet.this : key => subnet.id } }
