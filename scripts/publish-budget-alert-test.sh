#!/usr/bin/env bash

set -euo pipefail

TOPIC_NAME="${1:-gcp-billing-budget-alerts}"
THRESHOLD="${2:-0.9}"
COST_AMOUNT="${3:-1800}"
BUDGET_AMOUNT="${4:-3000}"
CURRENCY_CODE="${5:-JPY}"
BUDGET_NAME="${6:-Monthly GCP Budget}"

MESSAGE="$(printf '%s' "{\"budgetDisplayName\":\"${BUDGET_NAME}\",\"costAmount\":${COST_AMOUNT},\"budgetAmount\":${BUDGET_AMOUNT},\"alertThresholdExceeded\":${THRESHOLD},\"currencyCode\":\"${CURRENCY_CODE}\"}")"

gcloud pubsub topics publish "${TOPIC_NAME}" --message="${MESSAGE}"
