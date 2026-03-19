import client from "./client";
import type { TaskResult } from "@/types";

export function createTask(data: {
  style_id: number;
  model: string;
  size: string;
  reference_image?: string;
}): Promise<{ task_id: number }> {
  return client.post("/tasks", data);
}

export function getTask(taskId: number): Promise<TaskResult> {
  return client.get(`/tasks/${taskId}`);
}
