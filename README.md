# GCP Billing Notifier on Cloud Run

`Cloud Run` と Terraform を使って、GCP の課金状況を日次レポートと即時アラートで通知する最小構成です。

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

## Security Model

- `Pub/Sub -> Cloud Run` は OIDC token 付き authenticated push を使います
- `Cloud Scheduler -> Cloud Run` も OIDC token 付き authenticated HTTP を使います
- `Cloud Run -> LINE Messaging API` は HTTPS を使います
- `LINE_TOKEN` は既存の `Secret Manager` secret を再利用します
- Budget Alert では Pub/Sub 通知に加えて Billing Budget の既定 recipient に email も送られます
- そのため、公開 webhook を自前で晒す必要はありません

## Prerequisites

- Terraform `>= 1.14`
- Node.js `>= 24`
- GCP project
- GCP Billing Account
- Terraform 実行ユーザーに `Billing Account Administrator`
- Terraform 実行ユーザーに Cloud Run, Scheduler, Pub/Sub, Artifact Registry, IAM, Secret Manager を扱う権限
- `Cloud Build` の実行 identity に Terraform apply と backend bucket 参照に必要な権限
- `LINE_TOKEN` という名前の Secret Manager secret が既に存在すること
- `cloudbuild.googleapis.com`
- `run.googleapis.com`
- `billingbudgets.googleapis.com`
  が有効であること

## Files

```text
.
├── AGENTS.md
├── .env.local.example
├── cloudbuild.yaml
├── Dockerfile
├── Makefile
├── README.md
├── package.json
├── scripts
│   ├── check-billing-export-table.sh
│   ├── publish-budget-alert-test.sh
│   └── run-daily-report-test.sh
├── src
│   ├── app.ts
│   ├── bigquery.ts
│   ├── config.ts
│   ├── index.ts
│   ├── line.ts
│   ├── messages.ts
│   ├── pubsub.ts
│   └── types.ts
├── terraform
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
├── test
│   └── app.test.ts
└── tests
    └── smoke.sh
```

## Environment

Cloud Run には以下を注入します。

- `GCP_PROJECT_ID`
- `BILLING_DATASET_ID`
- `BILLING_ACCOUNT_TABLE_SUFFIX`
- `LINE_TO`
- `LINE_CHANNEL_ACCESS_TOKEN`

`LINE_CHANNEL_ACCESS_TOKEN` は Secret Manager の `LINE_TOKEN` から注入し、secret 自体は Terraform import しません。

## Local Shortcuts

public repo 向けに、実値は `.env.local` に分離し、`Makefile` は一般的な操作ショートカットだけを保持します。

```bash
cp .env.local.example .env.local
```

`.env.local` に入れる主な値:

- `PROJECT_ID`
- `BILLING_ACCOUNT_ID`
- `DATASET_ID`
- `DATASET_LOCATION`
- `BUDGET_DISPLAY_NAME`
- `BUDGET_AMOUNT`
- `BUDGET_CURRENCY`
- `CLOUD_RUN_REGION`
- `ARTIFACT_REGISTRY_REPOSITORY_ID`
- `CLOUD_RUN_SERVICE_NAME`
- `CONTAINER_IMAGE_TAG`
- `PUBSUB_TOPIC_NAME`
- `PUBSUB_SUBSCRIPTION_NAME`
- `SCHEDULER_JOB_NAME`
- `SCHEDULER_CRON`
- `SCHEDULER_TIME_ZONE`
- `LINE_TO`
- `LINE_TOKEN_SECRET_NAME`
- `TF_STATE_BUCKET`
- `TF_STATE_PREFIX`

主なショートカット:

```bash
make alert-test
make table-check
make daily-test
make test
make build
make deploy
make tf-init
make tf-plan
make tf-apply CONFIRM=yes
```

`.env.local` は Git 管理しません。`terraform/terraform.tfvars` はローカル非常用です。

public に公開する場合も、tracked file には実際の `billing_account_id`、`LINE_TO`、service URL を含めない前提です。

## Bootstrap Sequence

通常運用は `Cloud Build` で build と deploy を完結させます。初回だけ `GCS backend` と state migration が必要です。

1. `GCS backend` 用 bucket を手動作成する
2. `.env.local.example` をコピーして `.env.local` を作る
3. 既存 local state がある場合は一度だけ `terraform init -migrate-state` で GCS に移す
4. `make deploy` で `Cloud Build -> build -> push -> terraform apply` を実行する
5. Cloud Billing console で BigQuery export を有効化する

backend bucket の推奨:

- location: `US`
- versioning: enabled
- uniform bucket-level access: enabled

既存 local state がある場合の migration:

```bash
terraform -chdir=terraform init -migrate-state \
  -backend-config="bucket=<tf_state_bucket>" \
  -backend-config="prefix=<tf_state_prefix>"
```

image URI は次の形式です。

```text
us-central1-docker.pkg.dev/<project_id>/<artifact_registry_repository_id>/<cloud_run_service_name>:<container_image_tag>
```

`Cloud Build` は次を実行します。

- `npm ci`
- `npm test`
- `npm run build`
- `docker build`
- `docker push`
- `terraform init` with `GCS backend`
- `terraform validate`
- `terraform apply`

`Makefile` を使う場合:

```bash
make deploy
```

個別コマンドで叩く場合:

```bash
gcloud builds submit --config cloudbuild.yaml --substitutions \
  "_PROJECT_ID=<project_id>,_BILLING_ACCOUNT_ID=<billing_account_id>,_BUDGET_AMOUNT=<budget_amount>,_LINE_TO=<line_to>,_TF_STATE_BUCKET=<tf_state_bucket>,_TF_STATE_PREFIX=<tf_state_prefix>"
```

local で emergency plan/apply を行う場合:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
make tf-plan
make tf-apply CONFIRM=yes
```

`make tf-plan` / `make tf-apply` は `terraform/terraform.tfvars` を読むので、先にそのファイルを作成しておく必要があります。`make tf-init` は `TF_STATE_BUCKET` と `TF_STATE_PREFIX` を使って `GCS backend` を初期化します。

Billing Budget API を local ADC で叩くため、初回は quota project 設定も必要です。

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project <project_id>
```

## Terraform Variables

- `project_id`: GCP project ID
- `billing_account_id`: Billing account ID
- `dataset_id`: Billing export 用 dataset ID
- `dataset_location`: BigQuery location。推奨は `US`
- `budget_amount`: 予算額
- `budget_thresholds`: 通知しきい値。例: `[0.5, 0.9, 1.0]`
- `cloud_run_service_name`: Cloud Run service 名
- `cloud_run_region`: Cloud Run / Scheduler / Artifact Registry の region。推奨は `us-central1`
- `artifact_registry_repository_id`: container image repository 名
- `line_to`: LINE の送信先 ID
- `line_token_secret_name`: 既存 secret 名。既定値は `LINE_TOKEN`

## BigQuery Export Notes

- `hashicorp/google` provider v6.50.0 には Cloud Billing usage export を直接管理する resource はありません
- そのため、usage export の有効化は Cloud Billing console で manual に実施してください
- Billing export の反映には数時間から 24 時間程度の遅延があります
- Daily Report は export table が作成されるまで成功しません
- エクスポートテーブル名は通常 `gcp_billing_export_v1_<billing_account_id_with_underscores>` です
- Terraform output の `billing_export_table_name_hint` を確認に使えます

## Tests

```bash
npm test
npm run build
bash tests/smoke.sh
cd terraform && terraform validate
```

## Manual Checks

Budget Alert の手動テスト:

```bash
bash scripts/publish-budget-alert-test.sh
```

引数:
- `1`: topic 名
- `2`: threshold。例 `0.9`
- `3`: costAmount
- `4`: budgetAmount
- `5`: currencyCode
- `6`: budgetDisplayName

例:

```bash
bash scripts/publish-budget-alert-test.sh gcp-billing-budget-alerts 1.0 3200 3000 JPY "Monthly GCP Budget"
```

Cloud Run logs:

```bash
gcloud run services logs read google-billing-notifier --region=us-central1 --limit=20
```

成功時は `budget alert delivered` または `daily report delivered` の要約ログが出ます。

Billing export table の確認:

```bash
bash scripts/check-billing-export-table.sh <project_id> gcp_billing_export <billing_account_id>
```

引数:
- `1`: project_id。未指定なら `gcloud config get-value project`
- `2`: dataset_id。既定値は `gcp_billing_export`
- `3`: billing_account_id。必須

Daily Report の手動実行:

```bash
bash scripts/run-daily-report-test.sh
```

引数:
- `1`: Scheduler job 名。既定値は `gcp-billing-daily-report`
- `2`: location。既定値は `us-central1`
- `3`: Cloud Run service 名。既定値は `google-billing-notifier`

確認手順:
1. `bash scripts/check-billing-export-table.sh <project_id> gcp_billing_export <billing_account_id>`
2. 成功したら `bash scripts/run-daily-report-test.sh`
3. LINE 通知と Cloud Run logs の `daily report delivered` を確認

個別コマンドで叩く場合:

```bash
gcloud scheduler jobs run gcp-billing-daily-report --location=us-central1
```
