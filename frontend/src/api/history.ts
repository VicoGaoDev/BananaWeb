import client from "./client";
import type { HistoryResponse } from "@/types";

export function fetchHistory(page: number = 1, pageSize: number = 20): Promise<HistoryResponse> {
  return client.get("/history", { params: { page, page_size: pageSize } });
}

export function deleteHistoryTask(taskId: number): Promise<void> {
  return client.delete(`/history/${taskId}`);
}
