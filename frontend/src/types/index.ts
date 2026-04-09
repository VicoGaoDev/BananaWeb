export interface UserInfo {
  id: number;
  username: string;
  role: "user" | "admin" | "superadmin";
  avatar_url?: string;
}

export interface LoginResponse {
  token: string;
  user: UserInfo;
}

export interface ImageResult {
  id: number;
  image_url: string;
  status: "pending" | "success" | "failed";
}

export interface TaskResult {
  id: number;
  prompt: string;
  num_images: number;
  size: string;
  status: "pending" | "processing" | "success" | "failed";
  created_at: string;
  images: ImageResult[];
}

export interface HistoryItem {
  task_id: number;
  username?: string;
  avatar_url?: string;
  prompt: string;
  reference_images: string[];
  size: string;
  status: string;
  created_at: string;
  images: ImageResult[];
}

export interface HistoryFilter {
  status?: string;
  user_id?: number;
  start_date?: string;
  end_date?: string;
}

export interface HistoryResponse {
  total: number;
  items: HistoryItem[];
}

export interface AdminUser {
  id: number;
  username: string;
  avatar_url?: string;
  role: string;
  status: string;
  created_at: string;
}

export interface AdminStats {
  last_7_days: number;
  last_30_days: number;
  total_users: number;
  active_users: number;
}
