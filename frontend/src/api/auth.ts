import client from "./client";
import type { LoginResponse, UserInfo } from "@/types";

export function login(username: string, password: string): Promise<LoginResponse> {
  return client.post("/auth/login", { username, password });
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
