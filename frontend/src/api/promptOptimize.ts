import client from "./client";

export function optimizePrompt(data: {
  prompt: string;
  reference_images?: string[];
}, signal?: AbortSignal): Promise<{ prompt: string }> {
  return client.post("/prompt-optimize", data, { signal });
}
