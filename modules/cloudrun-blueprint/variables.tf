variable "config_file" {
  type        = string
  description = "Path to the service.yaml configuration file"
}

variable "image_tag" {
  type        = string
  description = "Container image tag to deploy"
  default     = "latest"
}

variable "shared_vpc_network" {
  type        = string
  description = "Shared VPC network for the VPC connector"
  default     = null
}

variable "vpc_connector_cidr" {
  type        = string
  description = "CIDR range (/28) for the serverless VPC connector"
  default     = "10.8.0.0/28"
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable Cloud Monitoring alert policy for 5xx errors"
  default     = true
}
