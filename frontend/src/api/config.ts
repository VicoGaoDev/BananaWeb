import client from "./client";
import type { GenerationModelOption, TaskSceneConfig } from "@/types";

export function getGenerationModels(): Promise<GenerationModelOption[]> {
  return client.get("/config/generation-models");
}

export function getTaskScenes(): Promise<TaskSceneConfig[]> {
  return client.get("/config/task-scenes");
}
