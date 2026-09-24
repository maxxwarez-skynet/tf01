module "machine" {
  for_each            = var.config.machines
  source              = "../../../modules/azure/compute"
  name                = each.value.name
  resource_group_name = var.foundation.resource_group_name
  location            = var.config.location
  zone                = var.config.zone
  subnet_id           = var.foundation.subnet_ids["web"]
  size                = each.value.size
  public_ports        = each.value.public_ports
  admin_username      = var.config.admin_username
  ssh_public_key      = var.ssh_public_key
  admin_cidrs         = var.admin_cidrs
  image               = var.config.image
  tags                = merge(var.config.tags, { machine = each.key })
}
resource "azurerm_role_assignment" "secrets_reader" {
  for_each                         = var.config.machines
  scope                            = var.key_vault_id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = module.machine[each.key].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
