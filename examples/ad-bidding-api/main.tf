module "service" {
  source      = "../../modules/cloudrun-blueprint"
  config_file = "${path.module}/service.yaml"
  image_tag   = var.image_tag
}

variable "image_tag" {
  type        = string
  description = "Container image tag to deploy"
  default     = "latest"
}

output "service_url" {
  value = module.service.service_url
}

output "service_account_email" {
  value = module.service.service_account_email
}

output "revision" {
  value = module.service.revision
}
