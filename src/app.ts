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

async function deliverLineMessage(
  response: ServerResponse,
  dependencies: AppDependencies,
  logger: Pick<Console, "info">,
  message: string,
  successLabel: string,
  successContext: Record<string, unknown>,
): Promise<void> {
  await pushLineMessage(
    dependencies.fetchImpl,
    dependencies.config.lineChannelAccessToken,
    dependencies.config.lineTo,
    message,
  );

  logger.info(successLabel, successContext);
  writeJson(response, 200, { ok: true });
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
      const thresholdPercent = Math.round(payload.alertThresholdExceeded * 100);

      if (payload.alertThresholdExceeded <= 0) {
        logger.info("budget alert skipped", {
          path: request.url,
          budgetDisplayName: payload.budgetDisplayName,
          thresholdPercent,
          costAmount: payload.costAmount,
          budgetAmount: payload.budgetAmount,
        });
        writeJson(response, 200, { ok: true, skipped: true });
        return;
      }

      const message = buildBudgetAlertMessage(payload);

      await deliverLineMessage(
        response,
        dependencies,
        logger,
        message,
        "budget alert delivered",
        {
        path: request.url,
        budgetDisplayName: payload.budgetDisplayName,
        thresholdPercent,
        costAmount: payload.costAmount,
        budgetAmount: payload.budgetAmount,
        },
      );
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

      await deliverLineMessage(
        response,
        dependencies,
        logger,
        message,
        "daily report delivered",
        {
        path: request.url,
        totalCost: summary.totalCost,
        yesterdayCost: summary.yesterdayCost,
        },
      );
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
