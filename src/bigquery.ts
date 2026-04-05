import type { BigQueryClientLike, BillingSummary } from "./types.js";

export function buildBillingQuery(projectId: string, datasetId: string, billingAccountTableSuffix: string): string {
  return `SELECT
  SUM(cost) AS total_cost,
  SUM(IF(DATE(usage_start_time) = DATE_SUB(CURRENT_DATE('Asia/Tokyo'), INTERVAL 1 DAY), cost, 0)) AS yesterday_cost
FROM
  \`${projectId}.${datasetId}.gcp_billing_export_resource_v1_${billingAccountTableSuffix}\`
WHERE
  invoice.month = FORMAT_DATE("%Y%m", CURRENT_DATE('Asia/Tokyo'))`;
}

function readCost(row: Record<string, unknown>, key: string): number {
  return Number(row[key] ?? 0);
}

export async function queryBillingSummary(
  client: BigQueryClientLike,
  projectId: string,
  datasetId: string,
  billingAccountTableSuffix: string,
): Promise<BillingSummary> {
  const query = buildBillingQuery(projectId, datasetId, billingAccountTableSuffix);
  const [rows] = await client.query(query);
  const firstRow = rows[0] ?? {};

  return {
    totalCost: readCost(firstRow, "total_cost"),
    yesterdayCost: readCost(firstRow, "yesterday_cost"),
  };
}
