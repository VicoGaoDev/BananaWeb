import client from "./client";
import type { LoginResponse, UserInfo, CreditLog, AnnouncementConfig, PromptHistoryItem } from "@/types";

export function login(username: string, password: string): Promise<LoginResponse> {
  return client.post("/auth/login", { username, password });
}

export function register(username: string, password: string): Promise<LoginResponse> {
  return client.post("/auth/register", { username, password });
}

export function changePassword(oldPassword: string, newPassword: string): Promise<any> {
  return client.post("/auth/change-password", {
    old_password: oldPassword,
    new_password: newPassword,
  });
}

export function getMe(): Promise<UserInfo> {
  return client.get("/auth/me");
}

export function uploadAvatar(file: File): Promise<UserInfo> {
  const formData = new FormData();
  formData.append("file", file);
  return client.post("/auth/avatar", formData, {
    headers: { "Content-Type": "multipart/form-data" },
  });
}

export function getPromptHistory(): Promise<PromptHistoryItem[]> {
  return client.get("/auth/prompt-history");
}

export function deletePromptHistory(id: number): Promise<void> {
  return client.delete(`/auth/prompt-history/${id}`);
}

export function getCreditLogs(params: {
  page?: number;
  page_size?: number;
  user_id?: number;
  start_date?: string;
  end_date?: string;
  direction?: "increase" | "decrease";
  mode?: "generate" | "inpaint" | "promptReverse" | "manual";
}): Promise<{ total: number; items: CreditLog[] }> {
  return client.get("/auth/credit-logs", { params });
}

export function getContactConfig(): Promise<{ contact_qr_image: string }> {
  return client.get("/config/contact");
}

export function getAnnouncementConfig(): Promise<AnnouncementConfig> {
  return client.get("/config/announcement");
}
