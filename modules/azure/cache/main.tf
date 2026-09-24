resource "azurerm_managed_redis" "this" {
  name                      = var.name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  sku_name                  = var.sku
  high_availability_enabled = false
  public_network_access     = "Disabled"
  default_database {
    client_protocol                    = "Encrypted"
    clustering_policy                  = "NoCluster"
    access_keys_authentication_enabled = true
  }
  tags = var.tags
}
resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${var.name}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}
resource "azurerm_private_endpoint" "this" {
  name                = "${var.name}-pe"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id
  tags                = var.tags
  private_service_connection {
    name                           = "${var.name}-connection"
    private_connection_resource_id = azurerm_managed_redis.this.id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "redis"
    private_dns_zone_ids = [azurerm_private_dns_zone.this.id]
  }
}
