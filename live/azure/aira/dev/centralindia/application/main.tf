data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = merge(var.state_backend, {
    key              = "${local.state_prefix}/foundation.tfstate"
    use_azuread_auth = true
  })
}
data "terraform_remote_state" "data" {
  backend = "azurerm"
  config = merge(var.state_backend, {
    key              = "${local.state_prefix}/data.tfstate"
    use_azuread_auth = true
  })
}
module "application" {
  source         = "../../../../../../blueprints/azure/application"
  config         = merge(local.config, { image = merge(local.config.image, { version = var.ubuntu_image_version }) })
  foundation     = data.terraform_remote_state.foundation.outputs
  key_vault_id   = data.terraform_remote_state.data.outputs.key_vault_id
  ssh_public_key = var.ssh_public_key
  admin_cidrs    = var.admin_cidrs
}
