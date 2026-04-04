import type { IncomingMessage, ServerResponse } from "node:http";

import { buildDailyReportMessage, buildBudgetAlertMessage } from "./messages.js";
import { parseBudgetAlertEnvelope } from "./pubsub.js";
import { pushLineMessage } from "./line.js";
import { queryBillingSummary } from "./bigquery.js";
import type { AppConfig, BigQueryClientLike, FetchLike } from "./types.js";

export interface AppDependencies {
  config: AppConfig;
  bigQueryClient: BigQueryClientLike;
  fetchImpl: FetchLike;
  logger?: Pick<Console, "error" | "info">;
}

async function readJsonBody(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];

  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  if (chunks.length === 0) {
    return {};
  }

  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function writeJson(response: ServerResponse, statusCode: number, body: Record<string, unknown>): void {
  response.writeHead(statusCode, { "Content-Type": "application/json" });
  response.end(JSON.stringify(body));
}

export async function handleRequest(
  request: IncomingMessage,
  response: ServerResponse,
  dependencies: AppDependencies,
): Promise<void> {
  const logger = dependencies.logger ?? console;

  try {
    if (request.method === "GET" && request.url === "/healthz") {
      writeJson(response, 200, { ok: true });
      return;
    }

    if (request.method === "POST" && request.url === "/pubsub/budget-alert") {
      const body = await readJsonBody(request);
      const payload = parseBudgetAlertEnvelope(body);
      const message = buildBudgetAlertMessage(payload);

      await pushLineMessage(
        dependencies.fetchImpl,
        dependencies.config.lineChannelAccessToken,
        dependencies.config.lineTo,
        message,
      );

      logger.info("budget alert delivered", {
        path: request.url,
        budgetDisplayName: payload.budgetDisplayName,
        thresholdPercent: Math.round(payload.alertThresholdExceeded * 100),
        costAmount: payload.costAmount,
        budgetAmount: payload.budgetAmount,
      });

      writeJson(response, 200, { ok: true });
      return;
    }

    if (request.method === "POST" && request.url === "/tasks/daily-report") {
      const summary = await queryBillingSummary(
        dependencies.bigQueryClient,
        dependencies.config.projectId,
        dependencies.config.billingDatasetId,
        dependencies.config.billingAccountTableSuffix,
      );
      const message = buildDailyReportMessage(summary);

      await pushLineMessage(
        dependencies.fetchImpl,
        dependencies.config.lineChannelAccessToken,
        dependencies.config.lineTo,
        message,
      );

      logger.info("daily report delivered", {
        path: request.url,
        totalCost: summary.totalCost,
        yesterdayCost: summary.yesterdayCost,
      });

      writeJson(response, 200, { ok: true });
      return;
    }

    writeJson(response, 404, { ok: false, error: "Not Found" });
  } catch (error) {
    logger.error("request failed", {
      path: request.url,
      method: request.method,
      error: error instanceof Error ? error.message : "Unknown error",
    });
    writeJson(response, 500, {
      ok: false,
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
}
