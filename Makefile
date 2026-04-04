SHELL := /bin/bash

ifneq (,$(wildcard .env.local))
include .env.local
export
endif

PROJECT_ID ?=
BILLING_ACCOUNT_ID ?=
DATASET_ID ?= gcp_billing_export
DATASET_LOCATION ?= US
BUDGET_DISPLAY_NAME ?= Monthly GCP Budget
BUDGET_AMOUNT ?=
BUDGET_CURRENCY ?= JPY
CLOUD_RUN_REGION ?= us-central1
ARTIFACT_REGISTRY_REPOSITORY_ID ?= google-billing-notifier
CLOUD_RUN_SERVICE_NAME ?= google-billing-notifier
CONTAINER_IMAGE_TAG ?= latest
PUBSUB_TOPIC_NAME ?= gcp-billing-budget-alerts
PUBSUB_SUBSCRIPTION_NAME ?= gcp-billing-budget-alerts-to-cloud-run
SCHEDULER_JOB_NAME ?= gcp-billing-daily-report
SCHEDULER_CRON ?= 0 9 * * *
SCHEDULER_TIME_ZONE ?= Asia/Tokyo
LINE_TO ?=
LINE_TOKEN_SECRET_NAME ?= LINE_TOKEN
TF_STATE_BUCKET ?=
TF_STATE_PREFIX ?= terraform/google-billing-notifier

IMAGE_URI := $(CLOUD_RUN_REGION)-docker.pkg.dev/$(PROJECT_ID)/$(ARTIFACT_REGISTRY_REPOSITORY_ID)/$(CLOUD_RUN_SERVICE_NAME):$(CONTAINER_IMAGE_TAG)
TF_BACKEND_FLAGS := -backend-config=bucket=$(TF_STATE_BUCKET) -backend-config=prefix=$(TF_STATE_PREFIX)

.PHONY: alert-test table-check daily-test test build push-image deploy tf-init tf-plan tf-apply

define require_env
	@if [[ -z "$($1)" ]]; then \
		echo "$1 is required. Set it in .env.local or pass it on the command line." >&2; \
		exit 1; \
	fi
endef

alert-test:
	$(call require_env,PUBSUB_TOPIC_NAME)
	$(call require_env,BILLING_ACCOUNT_ID)
	bash scripts/publish-budget-alert-test.sh "$(PUBSUB_TOPIC_NAME)"

table-check:
	$(call require_env,PROJECT_ID)
	$(call require_env,BILLING_ACCOUNT_ID)
	bash scripts/check-billing-export-table.sh "$(PROJECT_ID)" "$(DATASET_ID)" "$(BILLING_ACCOUNT_ID)"

daily-test:
	$(call require_env,SCHEDULER_JOB_NAME)
	$(call require_env,CLOUD_RUN_REGION)
	$(call require_env,CLOUD_RUN_SERVICE_NAME)
	bash scripts/run-daily-report-test.sh "$(SCHEDULER_JOB_NAME)" "$(CLOUD_RUN_REGION)" "$(CLOUD_RUN_SERVICE_NAME)"

test:
	npm test

build:
	npm run build

push-image:
	$(call require_env,PROJECT_ID)
	$(call require_env,CLOUD_RUN_REGION)
	$(call require_env,ARTIFACT_REGISTRY_REPOSITORY_ID)
	$(call require_env,CLOUD_RUN_SERVICE_NAME)
	$(call require_env,CONTAINER_IMAGE_TAG)
	gcloud builds submit --tag "$(IMAGE_URI)"

deploy:
	$(call require_env,PROJECT_ID)
	$(call require_env,BILLING_ACCOUNT_ID)
	$(call require_env,BUDGET_AMOUNT)
	$(call require_env,LINE_TO)
	$(call require_env,TF_STATE_BUCKET)
	$(call require_env,TF_STATE_PREFIX)
	gcloud builds submit --config cloudbuild.yaml --substitutions "_PROJECT_ID=$(PROJECT_ID),_BILLING_ACCOUNT_ID=$(BILLING_ACCOUNT_ID),_DATASET_ID=$(DATASET_ID),_DATASET_LOCATION=$(DATASET_LOCATION),_BUDGET_DISPLAY_NAME=$(BUDGET_DISPLAY_NAME),_BUDGET_AMOUNT=$(BUDGET_AMOUNT),_BUDGET_CURRENCY=$(BUDGET_CURRENCY),_CLOUD_RUN_REGION=$(CLOUD_RUN_REGION),_ARTIFACT_REGISTRY_REPOSITORY_ID=$(ARTIFACT_REGISTRY_REPOSITORY_ID),_CLOUD_RUN_SERVICE_NAME=$(CLOUD_RUN_SERVICE_NAME),_CONTAINER_IMAGE_TAG=$(CONTAINER_IMAGE_TAG),_PUBSUB_TOPIC_NAME=$(PUBSUB_TOPIC_NAME),_PUBSUB_SUBSCRIPTION_NAME=$(PUBSUB_SUBSCRIPTION_NAME),_SCHEDULER_JOB_NAME=$(SCHEDULER_JOB_NAME),_SCHEDULER_CRON=$(SCHEDULER_CRON),_SCHEDULER_TIME_ZONE=$(SCHEDULER_TIME_ZONE),_LINE_TO=$(LINE_TO),_LINE_TOKEN_SECRET_NAME=$(LINE_TOKEN_SECRET_NAME),_TF_STATE_BUCKET=$(TF_STATE_BUCKET),_TF_STATE_PREFIX=$(TF_STATE_PREFIX)"

tf-init:
	$(call require_env,TF_STATE_BUCKET)
	$(call require_env,TF_STATE_PREFIX)
	terraform -chdir=terraform init -reconfigure $(TF_BACKEND_FLAGS)

tf-plan: tf-init
	terraform -chdir=terraform plan -var-file=terraform.tfvars

tf-apply: tf-init
	@if [[ "$(CONFIRM)" != "yes" ]]; then \
		echo "refusing to run terraform apply. Use: make tf-apply CONFIRM=yes" >&2; \
		exit 1; \
	fi
	terraform -chdir=terraform apply -var-file=terraform.tfvars
