variable "bucket_name" {
  type        = string
  description = "Globally unique recordings bucket name."
}
variable "tags" {
  type        = map(string)
  description = "Resource tags."
  default     = {}
}
variable "writer_role_names" {
  type        = set(string)
  description = "Existing AWS IAM roles to attach the recordings access policy to; no access keys are created."
  default     = []
}
