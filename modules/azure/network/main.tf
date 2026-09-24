resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}
resource "azurerm_subnet" "this" {
  for_each                          = var.subnets
  name                              = "snet-${each.key}-${var.name}"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [each.value]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = each.key == "cache" ? "NetworkSecurityGroupEnabled" : "Disabled"
  service_endpoints                 = each.key == "data" ? ["Microsoft.Storage"] : []
  dynamic "delegation" {
    for_each = each.key == "data" ? [1] : []
    content {
      name = "mysql"
      service_delegation {
        name    = "Microsoft.DBforMySQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}
# Protect private endpoints. Web access uses the actual Managed Redis TLS port.
resource "azurerm_network_security_group" "endpoints" {
  name                = "nsg-${var.name}-endpoints"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  security_rule {
    name                       = "WebToPrivateServices"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "10000"]
    source_address_prefix      = var.subnets["web"]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "DenyOtherInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "endpoints" {
  subnet_id                 = azurerm_subnet.this["cache"].id
  network_security_group_id = azurerm_network_security_group.endpoints.id
}
