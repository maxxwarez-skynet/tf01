mock_provider "azurerm" {
  mock_resource "azurerm_private_dns_zone" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/test.mysql.database.azure.com" }
  }
  mock_resource "azurerm_mysql_flexible_server" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforMySQL/flexibleServers/test" }
  }
}
variables {
  name                = "aira-test"
  resource_group_name = "rg-test"
  location            = "centralindia"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test/subnets/test"
  vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test"
  admin_password      = "OnlyForMockTests-42!"
}
run "private_without_ha" {
  command = plan
  assert {
    condition     = length(azurerm_mysql_flexible_server.this.high_availability) == 0 && !azurerm_mysql_flexible_server.this.geo_redundant_backup_enabled
    error_message = "Initial MySQL deployment must not enable HA or geo-redundant backup."
  }
  assert {
    condition     = azurerm_mysql_flexible_server.this.delegated_subnet_id == var.subnet_id && azurerm_mysql_flexible_server.this.backup_retention_days == 7
    error_message = "MySQL must use the private subnet and retain seven days of backups."
  }
  assert {
    condition     = azurerm_mysql_flexible_server_configuration.secure_transport.value == "ON"
    error_message = "MySQL must require encrypted connections."
  }
}
