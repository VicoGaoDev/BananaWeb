import client from "./client";
import type { GenerationModelOption } from "@/types";

export function getGenerationModels(): Promise<GenerationModelOption[]> {
  return client.get("/config/generation-models");
}
