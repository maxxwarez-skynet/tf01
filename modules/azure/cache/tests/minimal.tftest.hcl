mock_provider "azurerm" {
  mock_resource "azurerm_private_dns_zone" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.redis.azure.net" }
  }
  mock_resource "azurerm_managed_redis" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Cache/redisEnterprise/test" }
  }
}
variables {
  name                = "aira-test"
  resource_group_name = "rg-test"
  location            = "centralindia"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test/subnets/test"
  vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test"
}
run "private_without_ha" {
  command = plan
  assert {
    condition     = !azurerm_managed_redis.this.high_availability_enabled && azurerm_managed_redis.this.public_network_access == "Disabled"
    error_message = "Redis must have HA off and public network access disabled."
  }
  assert {
    condition     = azurerm_managed_redis.this.default_database[0].client_protocol == "Encrypted" && azurerm_managed_redis.this.sku_name == "Balanced_B0"
    error_message = "Redis must use TLS and the selected minimal SKU."
  }
  assert {
    condition     = azurerm_private_dns_zone.this.name == "privatelink.redis.azure.net"
    error_message = "Managed Redis needs its own private DNS suffix."
  }
}
