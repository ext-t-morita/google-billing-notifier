import type { AppConfig } from "./types.js";

function getRequiredEnv(env: NodeJS.ProcessEnv, name: string): string {
  const value = env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const portValue = env.PORT ?? "8080";
  const port = Number(portValue);
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error(`Invalid PORT: ${portValue}`);
  }

  return {
    port,
    projectId: getRequiredEnv(env, "GCP_PROJECT_ID"),
    billingDatasetId: getRequiredEnv(env, "BILLING_DATASET_ID"),
    billingAccountTableSuffix: getRequiredEnv(env, "BILLING_ACCOUNT_TABLE_SUFFIX"),
    lineTo: getRequiredEnv(env, "LINE_TO"),
    lineChannelAccessToken: getRequiredEnv(env, "LINE_CHANNEL_ACCESS_TOKEN"),
  };
}
