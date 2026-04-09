import client from "./client";
import type { TaskResult } from "@/types";

export function createTask(data: {
  prompt: string;
  num_images: number;
  size: string;
  resolution: string;
  reference_images?: string[];
}): Promise<{ task_id: number }> {
  return client.post("/tasks", data);
}

export function getTask(taskId: number): Promise<TaskResult> {
  return client.get(`/tasks/${taskId}`);
}
