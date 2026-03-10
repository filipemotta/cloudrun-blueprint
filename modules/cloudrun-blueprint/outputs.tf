output "service_url" {
  description = "The URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.name
}

output "service_account_email" {
  description = "The email of the per-service service account"
  value       = google_service_account.service.email
}

output "revision" {
  description = "The latest revision of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.latest_ready_revision
}

output "vpc_connector_id" {
  description = "The ID of the VPC connector (if created)"
  value       = try(google_vpc_access_connector.this[0].id, null)
}
