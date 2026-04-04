import type { BillingSummary, BudgetAlertPayload } from "./types.js";

function formatCurrency(amount: number, currency: string): string {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(amount);
}

export function buildDailyReportMessage(summary: BillingSummary): string {
  return [
    "【GCP Billing Daily Report】",
    `当月累計: ${formatCurrency(summary.totalCost, "JPY")}`,
    `前日分: ${formatCurrency(summary.yesterdayCost, "JPY")}`,
    "Billing export には反映遅延があるため、最新利用量と差が出る場合があります。",
  ].join("\n");
}

export function buildBudgetAlertMessage(payload: BudgetAlertPayload): string {
  const prefix = payload.alertThresholdExceeded >= 0.9 ? "【緊急】GCP Budget Alert" : "【GCP Budget Alert】";

  return [
    prefix,
    `Budget: ${payload.budgetDisplayName}`,
    `利用額: ${formatCurrency(payload.costAmount, payload.currencyCode)}`,
    `予算額: ${formatCurrency(payload.budgetAmount, payload.currencyCode)}`,
    `到達しきい値: ${Math.round(payload.alertThresholdExceeded * 100)}%`,
  ].join("\n");
}
