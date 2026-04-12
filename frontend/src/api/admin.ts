import client from "./client";
import type {
  AdminStats,
  ApiKeyConfig,
  AdminUser,
  CreditLog,
  ExternalApiConfig,
  ExternalApiConfigPayload,
  ExternalApiSceneBinding,
  ExternalApiConfigStatus,
  ExternalApiConfigTestResult,
  HistoryFilter,
  HistoryResponse,
} from "@/types";

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

export function resetUserPassword(userId: number, newPassword: string): Promise<AdminUser> {
  return client.put(`/admin/users/${userId}/reset-password`, { new_password: newPassword });
}

export function allocateCredits(userId: number, amount: number, description?: string): Promise<AdminUser> {
  return client.post(`/admin/users/${userId}/credits`, { amount, description: description || "" });
}

export function getCreditLogs(page = 1, pageSize = 20, userId?: number): Promise<{ total: number; items: CreditLog[] }> {
  const params: Record<string, unknown> = { page, page_size: pageSize };
  if (userId) params.user_id = userId;
  return client.get("/admin/credit-logs", { params });
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

export function getApiKey(): Promise<ApiKeyConfig | null> {
  return client.get("/admin/api-key");
}

export function setApiKey(payload: {
  key?: string;
  tongyi_key?: string;
  contact_qr_image?: string;
  announcement_enabled?: boolean;
  announcement_content?: string;
}): Promise<ApiKeyConfig> {
  return client.put("/admin/api-key", payload);
}

export function deleteApiKey(): Promise<void> {
  return client.delete("/admin/api-key");
}

export function listExternalApiConfigs(): Promise<ExternalApiConfig[]> {
  return client.get("/admin/external-api-configs");
}

export function createExternalApiConfig(payload: ExternalApiConfigPayload): Promise<ExternalApiConfig> {
  return client.post("/admin/external-api-configs", payload);
}

export function updateExternalApiConfig(configId: number, payload: ExternalApiConfigPayload): Promise<ExternalApiConfig> {
  return client.put(`/admin/external-api-configs/${configId}`, payload);
}

export function updateExternalApiConfigStatus(configId: number, status: ExternalApiConfigStatus): Promise<ExternalApiConfig> {
  return client.patch(`/admin/external-api-configs/${configId}/status`, { status });
}

export function listExternalApiSceneBindings(): Promise<ExternalApiSceneBinding[]> {
  return client.get("/admin/external-api-scene-bindings");
}

export function updateExternalApiSceneBinding(
  sceneKey: ExternalApiSceneBinding["scene_key"],
  apiConfigId: number | null,
): Promise<ExternalApiSceneBinding> {
  return client.put(`/admin/external-api-scene-bindings/${sceneKey}`, { api_config_id: apiConfigId });
}

export function testExternalApiConfig(payload: ExternalApiConfigPayload): Promise<ExternalApiConfigTestResult> {
  return client.post("/admin/external-api-configs/test", payload);
}
