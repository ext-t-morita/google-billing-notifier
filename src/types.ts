export interface BudgetAlertPayload {
  budgetDisplayName: string;
  costAmount: number;
  budgetAmount: number;
  alertThresholdExceeded: number;
  currencyCode: string;
}

export interface PubSubPushEnvelope {
  message?: {
    data?: string;
    messageId?: string;
    attributes?: Record<string, string>;
  };
  subscription?: string;
}

export interface BillingSummary {
  totalCost: number;
  yesterdayCost: number;
}

export interface AppConfig {
  port: number;
  projectId: string;
  billingDatasetId: string;
  billingAccountTableSuffix: string;
  lineTo: string;
  lineChannelAccessToken: string;
}

export interface BigQueryClientLike {
  query(query: string | { query: string }): Promise<[Array<Record<string, unknown>>, ...unknown[]]>;
}

export interface FetchLike {
  (input: string, init?: {
    method?: string;
    headers?: Record<string, string>;
    body?: string;
  }): Promise<{
    ok: boolean;
    status: number;
    text(): Promise<string>;
  }>;
}
