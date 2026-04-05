output "artifact_registry_repository_name" {
  description = "Artifact Registry repository name for container images."
  value       = google_artifact_registry_repository.container_images.name
}

output "cloud_run_image" {
  description = "Container image URI expected by Cloud Run."
  value       = local.cloud_run_image
}

output "cloud_run_service_url" {
  description = "Cloud Run service base URL."
  value       = google_cloud_run_v2_service.billing_notifier.uri
}

output "budget_alert_endpoint" {
  description = "Authenticated budget alert endpoint."
  value       = "${google_cloud_run_v2_service.billing_notifier.uri}/pubsub/budget-alert"
}

output "daily_report_endpoint" {
  description = "Authenticated daily report endpoint."
  value       = "${google_cloud_run_v2_service.billing_notifier.uri}/tasks/daily-report"
}

output "billing_export_table_name_hint" {
  description = "Expected detailed billing export table name pattern."
  value       = "gcp_billing_export_resource_v1_${local.billing_export_table_suffix}"
}

output "cloud_run_runtime_service_account_email" {
  description = "Service account email used by the Cloud Run runtime."
  value       = google_service_account.cloud_run_runtime.email
}
