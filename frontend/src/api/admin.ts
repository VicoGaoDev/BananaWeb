import client from "./client";
import type { AdminUser, AdminStats, HistoryResponse, HistoryFilter } from "@/types";

export function listUsers(): Promise<AdminUser[]> {
  return client.get("/admin/users");
}

export function createUser(data: { username: string; password: string; role?: string }): Promise<AdminUser> {
  return client.post("/admin/users", data);
}

export function updateUserStatus(userId: number, status: string): Promise<AdminUser> {
  return client.put(`/admin/users/${userId}/status`, { status });
}

export function updateUserRole(userId: number, role: string): Promise<AdminUser> {
  return client.put(`/admin/users/${userId}/role`, { role });
}

export function getStats(): Promise<AdminStats> {
  return client.get("/admin/stats");
}

export function getAdminHistory(
  page: number = 1,
  pageSize: number = 20,
  filter?: HistoryFilter,
): Promise<HistoryResponse> {
  const params: Record<string, unknown> = { page, page_size: pageSize };
  if (filter?.status) params.status = filter.status;
  if (filter?.user_id) params.user_id = filter.user_id;
  if (filter?.start_date) params.start_date = filter.start_date;
  if (filter?.end_date) params.end_date = filter.end_date;
  return client.get("/admin/history", { params });
}

export function getApiKey(): Promise<{ id: number; key: string; updated_at: string } | null> {
  return client.get("/admin/api-key");
}

export function setApiKey(key: string): Promise<{ id: number; key: string; updated_at: string }> {
  return client.put("/admin/api-key", { key });
}

export function deleteApiKey(): Promise<void> {
  return client.delete("/admin/api-key");
}
