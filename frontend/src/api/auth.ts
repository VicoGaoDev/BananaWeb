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
