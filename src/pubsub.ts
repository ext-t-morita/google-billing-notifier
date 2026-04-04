import type { BudgetAlertPayload, PubSubPushEnvelope } from "./types.js";

function asNumber(value: unknown, fieldName: string): number {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) {
    throw new Error(`Invalid numeric field: ${fieldName}`);
  }

  return numberValue;
}

export function parseBudgetAlertEnvelope(body: unknown): BudgetAlertPayload {
  const envelope = body as PubSubPushEnvelope;
  const encodedPayload = envelope.message?.data;
  if (!encodedPayload) {
    throw new Error("Pub/Sub message data is missing.");
  }

  const decoded = Buffer.from(encodedPayload, "base64").toString("utf8");
  const parsed = JSON.parse(decoded) as Record<string, unknown>;

  return {
    budgetDisplayName: String(parsed.budgetDisplayName ?? "Monthly GCP Budget"),
    costAmount: asNumber(parsed.costAmount, "costAmount"),
    budgetAmount: asNumber(parsed.budgetAmount, "budgetAmount"),
    alertThresholdExceeded: asNumber(parsed.alertThresholdExceeded, "alertThresholdExceeded"),
    currencyCode: String(parsed.currencyCode ?? "JPY"),
  };
}
