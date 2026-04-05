#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_file() {
  local path="$1"
  if [[ ! -f "$ROOT_DIR/$path" ]]; then
    echo "missing file: $path" >&2
    exit 1
  fi
}

assert_grep() {
  local pattern="$1"
  local path="$2"
  if ! grep -Eq "$pattern" "$ROOT_DIR/$path"; then
    echo "pattern not found: $pattern in $path" >&2
    exit 1
  fi
}

assert_not_grep() {
  local pattern="$1"
  local path="$2"
  if grep -Eq "$pattern" "$ROOT_DIR/$path"; then
    echo "unexpected pattern found: $pattern in $path" >&2
    exit 1
  fi
}

assert_json() {
  local path="$1"
  jq empty "$ROOT_DIR/$path" >/dev/null
}

assert_file "package.json"
assert_file "tsconfig.json"
assert_file "Dockerfile"
assert_file "Makefile"
assert_file ".env.local.example"
assert_file "cloudbuild.yaml"
assert_file "src/index.ts"
assert_file "src/app.ts"
assert_file "src/pubsub.ts"
assert_file "src/bigquery.ts"
assert_file "test/app.test.ts"
assert_file "scripts/publish-budget-alert-test.sh"
assert_file "scripts/check-billing-export-table.sh"
assert_file "scripts/run-daily-report-test.sh"
assert_file "terraform/main.tf"
assert_file "terraform/variables.tf"
assert_file "terraform/outputs.tf"
assert_file "terraform/versions.tf"
assert_file "terraform/terraform.tfvars.example"
assert_file "README.md"

assert_grep '"@google-cloud/bigquery"' "package.json"
assert_grep '"start": "node dist/src/index.js"' "package.json"
assert_grep '^\.env\.local$' ".gitignore"
assert_grep '^deploy:' "Makefile"
assert_grep '^tf-init:' "Makefile"
assert_grep '^tf-apply:' "Makefile"
assert_grep 'CONFIRM=yes' "Makefile"
assert_not_grep '^push-image:' "Makefile"
assert_grep '^PROJECT_ID=' ".env.local.example"
assert_grep '^TF_STATE_BUCKET=' ".env.local.example"
assert_grep '^TF_STATE_PREFIX=' ".env.local.example"
assert_not_grep '^CONTAINER_IMAGE_TAG=' ".env.local.example"
assert_grep 'terraform apply' "cloudbuild.yaml"
assert_grep 'terraform -chdir=terraform init' "cloudbuild.yaml"
assert_grep '_TF_STATE_BUCKET' "cloudbuild.yaml"
assert_grep 'BUILD_ID' "cloudbuild.yaml"
assert_grep 'docker push' "cloudbuild.yaml"
assert_grep 'backend "gcs"' "terraform/versions.tf"
assert_grep 'google_cloud_run_v2_service' "terraform/main.tf"
assert_grep 'google_cloud_scheduler_job' "terraform/main.tf"
assert_grep 'google_pubsub_subscription' "terraform/main.tf"
assert_grep 'google_artifact_registry_repository' "terraform/main.tf"
assert_grep 'roles/run.invoker' "terraform/main.tf"
assert_grep 'LINE_TOKEN' "terraform/terraform.tfvars.example"
assert_grep 'Cloud Run' "AGENTS.md"
assert_grep 'BigQuery export' "AGENTS.md"
assert_grep 'Cloud Run' "README.md"
assert_grep 'Secret Manager' "README.md"
assert_grep 'LINE_TOKEN' "README.md"
assert_grep 'Pub/Sub authenticated push' "README.md"
assert_grep 'publish-budget-alert-test.sh' "README.md"
assert_grep 'check-billing-export-table.sh' "README.md"
assert_grep 'run-daily-report-test.sh' "README.md"
assert_grep 'make tf-apply CONFIRM=yes' "README.md"
assert_grep 'cloudbuild.yaml' "README.md"
assert_grep 'GCS backend' "README.md"
assert_grep 'terraform init -migrate-state' "README.md"
assert_grep 'gcloud builds submit --config cloudbuild.yaml' "README.md"
assert_grep 'TF_STATE_BUCKET' "README.md"
assert_grep 'make deploy' "README.md"
assert_not_grep 'make push-image' "README.md"
assert_grep 'usage: bash scripts/check-billing-export-table.sh <project_id> .* <billing_account_id>' "scripts/check-billing-export-table.sh"
assert_not_grep 'n8n' "AGENTS.md"
assert_not_grep '0130F0-876117-CC6CB8' "README.md"
assert_not_grep '0130F0-876117-CC6CB8' "scripts/check-billing-export-table.sh"

echo "smoke tests passed"
