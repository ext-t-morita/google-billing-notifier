import type { FetchLike } from "./types.js";

export async function pushLineMessage(
  fetchImpl: FetchLike,
  accessToken: string,
  to: string,
  message: string,
): Promise<void> {
  const response = await fetchImpl("https://api.line.me/v2/bot/message/push", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      to,
      messages: [
        {
          type: "text",
          text: message,
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`LINE API request failed with status ${response.status}: ${await response.text()}`);
  }
}
