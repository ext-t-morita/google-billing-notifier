import { createServer } from "node:http";

import { BigQuery } from "@google-cloud/bigquery";

import { handleRequest } from "./app.js";
import { loadConfig } from "./config.js";

const config = loadConfig();
const bigQueryClient = new BigQuery({ projectId: config.projectId });

const server = createServer((request, response) => {
  void handleRequest(request, response, {
    config,
    bigQueryClient,
    fetchImpl: fetch,
  });
});

server.listen(config.port, () => {
  console.info(`google-billing-notifier listening on port ${config.port}`);
});
