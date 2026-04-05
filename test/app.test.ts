import test from "node:test";
import assert from "node:assert/strict";
import { PassThrough } from "node:stream";
import type { IncomingMessage, ServerResponse } from "node:http";

import { handleRequest } from "../src/app.js";
import { buildBillingQuery } from "../src/bigquery.js";
import { buildDailyReportMessage, buildBudgetAlertMessage } from "../src/messages.js";
import { parseBudgetAlertEnvelope } from "../src/pubsub.js";

test("buildBillingQuery uses Asia/Tokyo and billing export table suffix", () => {
  const query = buildBillingQuery("example-project", "billing_dataset", "0130F0_876117_CC6CB8");

  assert.match(query, /CURRENT_DATE\('Asia\/Tokyo'\)/);
  assert.match(query, /gcp_billing_export_resource_v1_0130F0_876117_CC6CB8/);
});

test("parseBudgetAlertEnvelope decodes Pub/Sub payload", () => {
  const payload = {
    budgetDisplayName: "Monthly GCP Budget",
    costAmount: 1800,
    budgetAmount: 3000,
    alertThresholdExceeded: 0.9,
    currencyCode: "JPY",
  };

  const encoded = Buffer.from(JSON.stringify(payload), "utf8").toString("base64");
  const parsed = parseBudgetAlertEnvelope({
    message: {
      data: encoded,
    },
  });

  assert.deepEqual(parsed, payload);
});

test("parseBudgetAlertEnvelope tolerates missing alert threshold", () => {
  const payload = {
    budgetDisplayName: "Monthly GCP Budget",
    costAmount: 1800,
    budgetAmount: 3000,
    currencyCode: "JPY",
  };

  const encoded = Buffer.from(JSON.stringify(payload), "utf8").toString("base64");
  const parsed = parseBudgetAlertEnvelope({
    message: {
      data: encoded,
    },
  });

  assert.equal(parsed.alertThresholdExceeded, 0);
});

test("buildBudgetAlertMessage marks urgent threshold", () => {
  const message = buildBudgetAlertMessage({
    budgetDisplayName: "Monthly GCP Budget",
    costAmount: 1800,
    budgetAmount: 3000,
    alertThresholdExceeded: 0.9,
    currencyCode: "JPY",
  });

  assert.match(message, /【緊急】/);
  assert.match(message, /90%/);
});

test("buildDailyReportMessage formats Yen", () => {
  const message = buildDailyReportMessage({
    totalCost: 1234,
    yesterdayCost: 210,
  });

  assert.match(message, /￥1,234|¥1,234/);
  assert.match(message, /￥210|¥210/);
});

function createRequest(method: string, url: string, body?: unknown): IncomingMessage {
  const request = new PassThrough() as PassThrough & IncomingMessage;
  request.method = method;
  request.url = url;

  if (body === undefined) {
    request.end();
  } else {
    request.end(JSON.stringify(body));
  }

  return request;
}

function createResponse() {
  let statusCode = 200;
  let body = "";

  const response = {
    writeHead(code: number) {
      statusCode = code;
      return this;
    },
    end(chunk?: string) {
      body = chunk ?? "";
      return this;
    },
  } as ServerResponse;

  return {
    response,
    get statusCode() {
      return statusCode;
    },
    get body() {
      return body;
    },
  };
}

test("handleRequest logs budget alert summary on success", async () => {
  const logs: unknown[][] = [];
  const logger = {
    info: (...args: unknown[]) => logs.push(args),
    error: (...args: unknown[]) => logs.push(args),
  };

  const request = createRequest("POST", "/pubsub/budget-alert", {
    message: {
      data: Buffer.from(
        JSON.stringify({
          budgetDisplayName: "Monthly GCP Budget",
          costAmount: 1800,
          budgetAmount: 3000,
          alertThresholdExceeded: 0.9,
          currencyCode: "JPY",
        }),
        "utf8",
      ).toString("base64"),
    },
  });
  const response = createResponse();

  await handleRequest(request, response.response, {
    config: {
      port: 8080,
      projectId: "example-project",
      billingDatasetId: "gcp_billing_export",
      billingAccountTableSuffix: "0130F0_876117_CC6CB8",
      lineTo: "group-id",
      lineChannelAccessToken: "token",
    },
    bigQueryClient: {
      query: async () => [[{}]],
    },
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      text: async () => "",
    }),
    logger,
  });

  assert.equal(response.statusCode, 200);
  assert.equal(logs.length, 1);
  const firstLog = logs[0];
  assert.ok(firstLog);
  assert.equal(firstLog[0], "budget alert delivered");
  assert.deepEqual(firstLog[1], {
    path: "/pubsub/budget-alert",
    budgetDisplayName: "Monthly GCP Budget",
    thresholdPercent: 90,
    costAmount: 1800,
    budgetAmount: 3000,
  });
});

test("handleRequest logs daily report summary on success", async () => {
  const logs: unknown[][] = [];
  const logger = {
    info: (...args: unknown[]) => logs.push(args),
    error: (...args: unknown[]) => logs.push(args),
  };
  const request = createRequest("POST", "/tasks/daily-report");
  const response = createResponse();

  await handleRequest(request, response.response, {
    config: {
      port: 8080,
      projectId: "example-project",
      billingDatasetId: "gcp_billing_export",
      billingAccountTableSuffix: "0130F0_876117_CC6CB8",
      lineTo: "group-id",
      lineChannelAccessToken: "token",
    },
    bigQueryClient: {
      query: async () => [[{ total_cost: 1234, yesterday_cost: 210 }]],
    },
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      text: async () => "",
    }),
    logger,
  });

  assert.equal(response.statusCode, 200);
  assert.equal(logs.length, 1);
  const firstLog = logs[0];
  assert.ok(firstLog);
  assert.equal(firstLog[0], "daily report delivered");
  assert.deepEqual(firstLog[1], {
    path: "/tasks/daily-report",
    totalCost: 1234,
    yesterdayCost: 210,
  });
});
