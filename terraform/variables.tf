variable "project_id" {
  description = "Target Google Cloud project ID."
  type        = string
}

variable "billing_account_id" {
  description = "Billing account ID. Either XXXXXX-XXXXXX-XXXXXX or billingAccounts/XXXXXX-XXXXXX-XXXXXX."
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset ID for billing export."
  type        = string
  default     = "gcp_billing_export"
}

variable "dataset_location" {
  description = "BigQuery dataset location."
  type        = string
  default     = "US"
}

variable "budget_display_name" {
  description = "Display name for the billing budget."
  type        = string
  default     = "Monthly GCP Budget"
}

variable "budget_amount" {
  description = "Budget amount in the selected currency."
  type        = number
}

variable "budget_currency" {
  description = "Currency code for the budget amount."
  type        = string
  default     = "JPY"
}

variable "budget_thresholds" {
  description = "Threshold percentages for budget notifications."
  type        = list(number)
  default     = [0.5, 0.9, 1.0]

  validation {
    condition     = length(var.budget_thresholds) > 0 && alltrue([for threshold in var.budget_thresholds : threshold > 0 && threshold <= 1.0])
    error_message = "budget_thresholds must contain values between 0 and 1."
  }
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name for the notifier."
  type        = string
  default     = "google-billing-notifier"
}

variable "cloud_run_region" {
  description = "Cloud Run and Scheduler region."
  type        = string
  default     = "us-central1"
}

variable "artifact_registry_repository_id" {
  description = "Artifact Registry repository for Cloud Run container images."
  type        = string
  default     = "google-billing-notifier"
}

variable "container_image_tag" {
  description = "Container image tag deployed to Cloud Run."
  type        = string
  default     = "latest"
}

variable "pubsub_topic_name" {
  description = "Pub/Sub topic name for budget alerts."
  type        = string
  default     = "gcp-billing-budget-alerts"
}

variable "pubsub_subscription_name" {
  description = "Pub/Sub push subscription name for the Cloud Run budget endpoint."
  type        = string
  default     = "gcp-billing-budget-alerts-to-cloud-run"
}

variable "scheduler_job_name" {
  description = "Cloud Scheduler job name for the daily billing report."
  type        = string
  default     = "gcp-billing-daily-report"
}

variable "scheduler_cron" {
  description = "Cron expression for the daily billing report."
  type        = string
  default     = "0 9 * * *"
}

variable "scheduler_time_zone" {
  description = "Time zone for the daily billing report schedule."
  type        = string
  default     = "Asia/Tokyo"
}

variable "cloud_run_runtime_service_account_id" {
  description = "Service account ID used by the Cloud Run runtime."
  type        = string
  default     = "billing-notifier-runtime"
}

variable "pubsub_push_service_account_id" {
  description = "Service account ID used by Pub/Sub to sign OIDC tokens."
  type        = string
  default     = "billing-notifier-pubsub"
}

variable "scheduler_service_account_id" {
  description = "Service account ID used by Cloud Scheduler to invoke Cloud Run."
  type        = string
  default     = "billing-notifier-scheduler"
}

variable "line_to" {
  description = "LINE recipient ID for notifications."
  type        = string
}

variable "line_token_secret_name" {
  description = "Existing Secret Manager secret name that stores the LINE channel access token."
  type        = string
  default     = "LINE_TOKEN"
}

variable "labels" {
  description = "Optional labels applied to supported resources."
  type        = map(string)
  default     = {}
}
