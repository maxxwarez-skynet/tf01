resource "azurerm_private_dns_zone" "this" {
  name                = "${var.name}.mysql.database.azure.com"
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
resource "azurerm_mysql_flexible_server" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  administrator_login          = var.admin_username
  administrator_password       = var.admin_password
  sku_name                     = var.sku
  version                      = var.mysql_version
  zone                         = var.zone
  delegated_subnet_id          = var.subnet_id
  private_dns_zone_id          = azurerm_private_dns_zone.this.id
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = false
  # HA intentionally omitted for the minimal deployment.
  storage {
    size_gb           = var.storage_gb
    auto_grow_enabled = true
  }
  tags       = var.tags
  depends_on = [azurerm_private_dns_zone_virtual_network_link.this]
}
resource "azurerm_mysql_flexible_server_configuration" "secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.this.name
  value               = "ON"
}
