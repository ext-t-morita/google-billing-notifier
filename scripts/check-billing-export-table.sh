#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"
DATASET_ID="${2:-gcp_billing_export}"
BILLING_ACCOUNT_ID="${3:-}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "project_id is required" >&2
  echo "usage: bash scripts/check-billing-export-table.sh <project_id> [dataset_id] <billing_account_id>" >&2
  exit 1
fi

if [[ -z "${BILLING_ACCOUNT_ID}" ]]; then
  echo "billing_account_id is required" >&2
  echo "usage: bash scripts/check-billing-export-table.sh <project_id> [dataset_id] <billing_account_id>" >&2
  exit 1
fi

TABLE_SUFFIX="${BILLING_ACCOUNT_ID//-/_}"
TABLE_ID="gcp_billing_export_resource_v1_${TABLE_SUFFIX}"

echo "checking table: ${PROJECT_ID}:${DATASET_ID}.${TABLE_ID}"

if bq show --project_id="${PROJECT_ID}" "${PROJECT_ID}:${DATASET_ID}.${TABLE_ID}" >/dev/null 2>&1; then
  echo "billing export table is ready"
  echo "table: ${PROJECT_ID}:${DATASET_ID}.${TABLE_ID}"
  exit 0
fi

echo "billing export table is not ready yet" >&2
echo "expected table: ${PROJECT_ID}:${DATASET_ID}.${TABLE_ID}" >&2
exit 1
