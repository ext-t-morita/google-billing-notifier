data "google_project" "current" {
  project_id = var.project_id
}

locals {
  billing_account_resource_name = startswith(var.billing_account_id, "billingAccounts/") ? var.billing_account_id : "billingAccounts/${var.billing_account_id}"
  billing_account_plain_id      = replace(local.billing_account_resource_name, "billingAccounts/", "")
  billing_export_table_suffix   = replace(local.billing_account_plain_id, "-", "_")
  budget_amount_units           = floor(var.budget_amount)
  budget_amount_nanos           = floor((var.budget_amount - local.budget_amount_units) * 1000000000)
  cloud_run_image               = "${var.cloud_run_region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository_id}/${var.cloud_run_service_name}:${var.container_image_tag}"
  cloud_run_runtime_roles = toset([
    "roles/bigquery.dataViewer",
    "roles/bigquery.jobUser",
  ])
  pubsub_service_agent = "service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_bigquery_dataset" "billing_export" {
  project                    = var.project_id
  dataset_id                 = var.dataset_id
  location                   = var.dataset_location
  description                = "GCP billing export dataset consumed by the Cloud Run notifier."
  delete_contents_on_destroy = false
  labels                     = var.labels
}

resource "google_pubsub_topic" "budget_alerts" {
  project = var.project_id
  name    = var.pubsub_topic_name
  labels  = var.labels
}

resource "google_artifact_registry_repository" "container_images" {
  project       = var.project_id
  location      = var.cloud_run_region
  repository_id = var.artifact_registry_repository_id
  description   = "Docker images for the Google billing notifier."
  format        = "DOCKER"
  labels        = var.labels
}

resource "google_service_account" "cloud_run_runtime" {
  project      = var.project_id
  account_id   = var.cloud_run_runtime_service_account_id
  display_name = "Cloud Run billing notifier runtime"
  description  = "Runs the billing notifier and accesses BigQuery plus Secret Manager."
}

resource "google_project_iam_member" "cloud_run_runtime_bigquery_roles" {
  for_each = local.cloud_run_runtime_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "line_token_accessor" {
  project   = var.project_id
  secret_id = var.line_token_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_runtime.email}"
}

resource "google_service_account" "pubsub_push_invoker" {
  project      = var.project_id
  account_id   = var.pubsub_push_service_account_id
  display_name = "Pub/Sub push invoker"
  description  = "Signs OIDC tokens for Pub/Sub authenticated push to Cloud Run."
}

resource "google_service_account_iam_member" "pubsub_token_creator" {
  service_account_id = google_service_account.pubsub_push_invoker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_service_account" "scheduler_invoker" {
  project      = var.project_id
  account_id   = var.scheduler_service_account_id
  display_name = "Scheduler invoker"
  description  = "Invokes the daily report endpoint on Cloud Run."
}

resource "google_cloud_run_v2_service" "billing_notifier" {
  project             = var.project_id
  name                = var.cloud_run_service_name
  location            = var.cloud_run_region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false
  labels              = var.labels

  template {
    service_account = google_service_account.cloud_run_runtime.email

    containers {
      image = local.cloud_run_image

      ports {
        container_port = 8080
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "BILLING_DATASET_ID"
        value = var.dataset_id
      }

      env {
        name  = "BILLING_ACCOUNT_TABLE_SUFFIX"
        value = local.billing_export_table_suffix
      }

      env {
        name  = "LINE_TO"
        value = var.line_to
      }

      env {
        name = "LINE_CHANNEL_ACCESS_TOKEN"

        value_source {
          secret_key_ref {
            secret  = var.line_token_secret_name
            version = "latest"
          }
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = var.project_id
  location = var.cloud_run_region
  name     = google_cloud_run_v2_service.billing_notifier.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_push_invoker.email}"
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.cloud_run_region
  name     = google_cloud_run_v2_service.billing_notifier.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_invoker.email}"
}

resource "google_pubsub_subscription" "budget_alerts_to_cloud_run" {
  project = var.project_id
  name    = var.pubsub_subscription_name
  topic   = google_pubsub_topic.budget_alerts.id

  ack_deadline_seconds       = 20
  message_retention_duration = "604800s"

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.billing_notifier.uri}/pubsub/budget-alert"

    oidc_token {
      service_account_email = google_service_account.pubsub_push_invoker.email
      audience              = google_cloud_run_v2_service.billing_notifier.uri
    }
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.pubsub_invoker,
    google_service_account_iam_member.pubsub_token_creator,
  ]
}

resource "google_billing_budget" "monthly_budget" {
  billing_account = local.billing_account_plain_id
  display_name    = var.budget_display_name

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(local.budget_amount_units)
      nanos         = local.budget_amount_nanos
    }
  }

  budget_filter {
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds

    content {
      threshold_percent = threshold_rules.value
    }
  }

  all_updates_rule {
    pubsub_topic                   = google_pubsub_topic.budget_alerts.id
    schema_version                 = "1.0"
    disable_default_iam_recipients = false
  }
}

resource "google_cloud_scheduler_job" "daily_report" {
  project     = var.project_id
  region      = var.cloud_run_region
  name        = var.scheduler_job_name
  description = "Triggers the daily billing report endpoint on Cloud Run."
  schedule    = var.scheduler_cron
  time_zone   = var.scheduler_time_zone

  http_target {
    uri         = "${google_cloud_run_v2_service.billing_notifier.uri}/tasks/daily-report"
    http_method = "POST"

    oidc_token {
      service_account_email = google_service_account.scheduler_invoker.email
      audience              = google_cloud_run_v2_service.billing_notifier.uri
    }
  }

  depends_on = [google_cloud_run_v2_service_iam_member.scheduler_invoker]
}
