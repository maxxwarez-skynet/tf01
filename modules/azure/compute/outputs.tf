output "id" { value = azurerm_linux_virtual_machine.this.id }
output "public_ip" { value = azurerm_public_ip.this.ip_address }
output "private_ip" { value = azurerm_network_interface.this.private_ip_address }
output "principal_id" { value = azurerm_linux_virtual_machine.this.identity[0].principal_id }
