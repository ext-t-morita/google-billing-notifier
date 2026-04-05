#!/usr/bin/env bash

set -euo pipefail

JOB_NAME="${1:-gcp-billing-daily-report}"
LOCATION="${2:-us-central1}"
SERVICE_NAME="${3:-google-billing-notifier}"

gcloud scheduler jobs run "${JOB_NAME}" --location="${LOCATION}"
echo "scheduler job triggered: ${JOB_NAME}"
echo "recent daily report logs:"
gcloud run services logs read "${SERVICE_NAME}" --region="${LOCATION}" --limit=50 | grep -E '/tasks/daily-report|daily report delivered|request failed' || true
