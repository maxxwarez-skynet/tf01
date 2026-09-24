# Central Azure state storage also holds this independently managed AWS state.
terraform {
  backend "azurerm" {}
}
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.aws_account_id]
}
module "recordings" {
  source            = "../../../../../../modules/aws/recordings"
  bucket_name       = var.bucket_name
  writer_role_names = var.writer_role_names
  tags = {
    product     = "aira"
    deployment  = var.deployment_id
    environment = var.environment
    managed_by  = "opentofu"
  }
}
output "bucket_name" { value = module.recordings.bucket_name }
output "access_policy_arn" { value = module.recordings.access_policy_arn }
