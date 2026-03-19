import client from "./client";
import type { AdminUser, AdminStats, HistoryResponse } from "@/types";

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

export function getAdminHistory(page: number = 1, pageSize: number = 20): Promise<HistoryResponse> {
  return client.get("/admin/history", { params: { page, page_size: pageSize } });
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
