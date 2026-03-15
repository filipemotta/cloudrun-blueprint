output "state_bucket" {
  description = "GCS bucket for Terraform remote state"
  value       = google_storage_bucket.tfstate.name
}

output "artifact_registry_repo" {
  description = "Artifact Registry repository for container images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.cloud_run_images.repository_id}"
}

output "deployer_service_account_email" {
  description = "Deployer service account email (Terraform apply)"
  value       = google_service_account.deployer.email
}

output "image_pusher_service_account_email" {
  description = "Image pusher service account email (Docker build + push)"
  value       = google_service_account.image_pusher.email
}

output "workload_identity_provider" {
  description = "Full WIF provider path for GitHub Actions auth"
  value       = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
}
