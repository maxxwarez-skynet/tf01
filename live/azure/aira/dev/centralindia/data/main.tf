data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = merge(var.state_backend, {
    key              = "${local.state_prefix}/foundation.tfstate"
    use_azuread_auth = true
  })
}
module "data" {
  source         = "../../../../../../blueprints/azure/data"
  config         = local.config
  foundation     = data.terraform_remote_state.foundation.outputs
  mysql_password = var.mysql_password
  key_vault_name = var.key_vault_name
}
