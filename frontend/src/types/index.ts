export interface UserInfo {
  id: number;
  username: string;
  role: "user" | "admin";
  avatar_url?: string;
}

export interface LoginResponse {
  token: string;
  user: UserInfo;
}

export interface Style {
  id: number;
  name: string;
  cover_image: string;
  description: string;
}

export interface StylePrompt {
  id: number;
  style_id: number;
  prompt: string;
  negative_prompt: string;
  sort_order: number;
}

export interface ImageResult {
  id: number;
  image_url: string;
  status: "pending" | "success" | "failed";
}

export interface TaskResult {
  id: number;
  style_id: number;
  model: string;
  size: string;
  status: "pending" | "processing" | "success" | "failed";
  created_at: string;
  images: ImageResult[];
}

export interface HistoryItem {
  task_id: number;
  username?: string;
  avatar_url?: string;
  style_name: string;
  model: string;
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
