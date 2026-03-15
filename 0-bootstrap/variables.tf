variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for resources"
  default     = "us-central1"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or username"
}

variable "github_repos" {
  type        = list(string)
  description = "List of GitHub repository names allowed to deploy via WIF"
}
