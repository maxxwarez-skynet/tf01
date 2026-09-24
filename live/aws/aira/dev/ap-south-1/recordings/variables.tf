variable "region" {
  type        = string
  description = "AWS region; match the deployment path."
  default     = "ap-south-1"
}
variable "aws_account_id" {
  type        = string
  description = "Expected AWS account ID; prevents applying to the wrong account."
}
variable "bucket_name" {
  type        = string
  description = "Globally unique recordings bucket name."
}
variable "deployment_id" {
  type        = string
  description = "Independent installation identifier."
  default     = "aira"
}
variable "environment" {
  type        = string
  description = "Lifecycle environment."
  default     = "dev"
}
variable "writer_role_names" {
  type        = set(string)
  description = "Existing AWS roles with an independently configured trust relationship."
  default     = []
}
