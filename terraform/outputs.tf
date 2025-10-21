output "cloud_run_service_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.mcp_slackbot.uri
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.mcp_slackbot.name
}

output "database_bucket_name" {
  description = "Name of the GCS bucket for database persistence"
  value       = google_storage_bucket.database.name
}

output "database_bucket_url" {
  description = "URL of the GCS bucket"
  value       = google_storage_bucket.database.url
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository for Docker images"
  value       = google_artifact_registry_repository.mcp_slackbot.id
}

output "service_account_email" {
  description = "Email of the service account used by Cloud Run"
  value       = google_service_account.cloudrun.email
}

output "docker_push_command" {
  description = "Command to push Docker image to Artifact Registry"
  value       = "docker tag mcp-slackbot:latest ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.mcp_slackbot.repository_id}/mcp-slackbot:latest && docker push ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.mcp_slackbot.repository_id}/mcp-slackbot:latest"
}
