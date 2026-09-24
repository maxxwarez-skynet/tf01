module "deployment" {
  source      = "../../../../../../modules/deployment"
  config_file = "${path.module}/../deployment.json"
}
locals {
  config       = module.deployment.config
  state_prefix = module.deployment.state_prefix
}
