# AGENTS.md

## Purpose
- このリポジトリは、GCP Billing の通知を `Cloud Run` で処理する最小構成です
- 通知経路は 2 本です
- 1. `BigQuery export -> Cloud Scheduler -> Cloud Run -> LINE` の日次レポート
- 2. `Billing Budget -> Pub/Sub -> Cloud Run -> LINE` の即時アラート

## Current State
- `TypeScript` アプリは `src/` にあります
- Terraform は `terraform/` にあります
- 既存の `LINE_TOKEN` secret を `Secret Manager` から参照します
- 通常の deploy は `cloudbuild.yaml` 経由で `Cloud Build` から行います
- Terraform state は `GCS backend` を前提にします
- Cloud Billing の BigQuery export 有効化だけは Terraform ではなく console 手動です

## Source Of Truth
- 実装の source of truth は `README.md`、`terraform/`、`src/` です
- このファイルは現行構成の運用前提だけを簡潔に保持します

## Language
- 応答は日本語
- コード、コマンド、resource 名、API 名、SQL は英語のままでよい

## Architecture

### Daily Report
- GCP Billing export
- BigQuery dataset
- Cloud Scheduler authenticated HTTP
- Cloud Run `/tasks/daily-report`
- LINE Messaging API

### Immediate Alert
- GCP Billing Budget
- Pub/Sub topic
- Pub/Sub authenticated push
- Cloud Run `/pubsub/budget-alert`
- LINE Messaging API

## Terraform Scope
- `google_bigquery_dataset`
- `google_pubsub_topic`
- `google_pubsub_subscription`
- `google_billing_budget`
- `google_cloud_run_v2_service`
- `google_cloud_scheduler_job`
- runtime / invoker 用 service accounts と IAM
- Artifact Registry repository

## Manual Steps
- Cloud Billing の `Detailed usage cost` export を console で有効化する
- export 先 dataset は推奨 `US` location の `gcp_billing_export`
- BigQuery export table 作成まで数時間から 24 時間程度かかることがあります

## Recommended Defaults
- BigQuery dataset location は `US`
- Cloud Run / Scheduler / Artifact Registry は `us-central1`
- Budget Alert は LINE と email の両方を通知します

## Local Workflow
- 公開 repo には実値を含めません
- `.env.local` と `terraform/terraform.tfvars` はローカル専用です
- `Makefile` は generic なショートカットだけを保持します
- 通常運用は `make deploy`
- `tf-init` は `GCS backend` の `bucket` と `prefix` が必要です
- `make tf-apply` は `CONFIRM=yes` を必須にします

## Constraints
- Billing Account ID、LINE recipient、service URL の実値を tracked file に書かない
- secrets や credential はコミットしない
- service account key JSON は作らない前提です

## Validation
- 変更後は最低限 `npm test`、`npm run build`、`bash tests/smoke.sh` を実行する
- Terraform を変えた場合は `terraform validate` も実行する
