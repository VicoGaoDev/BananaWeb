import client from "./client";
import type { TaskResult } from "@/types";

export interface CreateTaskResponse {
  task_id?: number | null;
  task_ids: number[];
}

export function createTask(data: {
  model?: string;
  prompt: string;
  num_images: number;
  size: string;
  resolution: string;
  custom_size?: string;
  mode?: "generate" | "inpaint";
  reference_images?: string[];
  source_image?: string;
  mask_image?: string;
}): Promise<CreateTaskResponse> {
  return client.post("/tasks", data);
}

export function getTask(taskId: number): Promise<TaskResult> {
  return client.get(`/tasks/${taskId}`);
}

export function getTasks(taskIds: number[]): Promise<TaskResult[]> {
  const params = new URLSearchParams();
  taskIds.forEach((taskId) => {
    params.append("task_ids", String(taskId));
  });
  return client.get(`/tasks?${params.toString()}`);
}
