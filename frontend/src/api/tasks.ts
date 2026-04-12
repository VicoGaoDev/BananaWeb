import client from "./client";
import type { TaskResult } from "@/types";

export function createTask(data: {
  model?: string;
  prompt: string;
  num_images: number;
  size: string;
  resolution: string;
  mode?: "generate" | "inpaint";
  reference_images?: string[];
  source_image?: string;
  mask_image?: string;
}): Promise<{ task_id: number }> {
  return client.post("/tasks", data);
}

export function getTask(taskId: number): Promise<TaskResult> {
  return client.get(`/tasks/${taskId}`);
}
