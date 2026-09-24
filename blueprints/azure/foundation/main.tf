resource "azurerm_resource_group" "this" {
  name     = var.config.resource_group_name
  location = var.config.location
  tags     = var.config.tags
}
module "network" {
  source              = "../../../modules/azure/network"
  name                = "vnet-${var.config.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.config.location
  address_space       = var.config.address_space
  subnets             = var.config.subnets
  tags                = var.config.tags
}
