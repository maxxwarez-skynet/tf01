data "azurerm_client_config" "current" {}
module "mysql" {
  source                = "../../../modules/azure/mysql"
  name                  = var.config.mysql.name
  resource_group_name   = var.foundation.resource_group_name
  location              = var.config.location
  zone                  = var.config.zone
  subnet_id             = var.foundation.subnet_ids["data"]
  vnet_id               = var.foundation.vnet_id
  sku                   = var.config.mysql.sku
  mysql_version         = var.config.mysql.version
  storage_gb            = var.config.mysql.storage_gb
  backup_retention_days = var.config.mysql.backup_retention_days
  admin_username        = var.config.mysql.admin_username
  admin_password        = var.mysql_password
  tags                  = var.config.tags
}
module "cache" {
  source              = "../../../modules/azure/cache"
  name                = var.config.redis.name
  resource_group_name = var.foundation.resource_group_name
  location            = var.config.location
  subnet_id           = var.foundation.subnet_ids["cache"]
  vnet_id             = var.foundation.vnet_id
  sku                 = var.config.redis.sku
  tags                = var.config.tags
}
module "secrets" {
  source              = "../../../modules/azure/secrets"
  name                = var.key_vault_name
  resource_group_name = var.foundation.resource_group_name
  location            = var.config.location
  subnet_id           = var.foundation.subnet_ids["cache"]
  vnet_id             = var.foundation.vnet_id
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = var.config.tags
}
