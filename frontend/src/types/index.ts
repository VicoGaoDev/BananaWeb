export interface UserInfo {
  id: number;
  username: string;
  role: "user" | "admin" | "superadmin";
  avatar_url?: string;
  credits: number;
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
  model: string;
  prompt: string;
  num_images: number;
  size: string;
  resolution: string;
  status: "pending" | "processing" | "success" | "failed";
  created_at: string;
  images: ImageResult[];
}

export interface HistoryItem {
  task_id: number;
  username?: string;
  avatar_url?: string;
  model: string;
  prompt: string;
  reference_images: string[];
  num_images: number;
  size: string;
  resolution: string;
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
  credits: number;
  created_at: string;
}

export interface CreditLog {
  id: number;
  user_id: number;
  username: string;
  amount: number;
  type: "allocate" | "consume";
  description: string;
  operator_name: string;
  task_id?: number;
  created_at: string;
}

export interface TemplateTag {
  id: number;
  name: string;
}

export interface CreativeTemplate {
  id: number;
  prompt: string;
  model: string;
  reference_images: string[];
  num_images: number;
  size: string;
  resolution: string;
  result_image: string;
  tags: TemplateTag[];
  created_at: string;
}

export interface AdminStats {
  last_7_days: number;
  last_30_days: number;
  total_users: number;
  active_users: number;
}

export interface ApiKeyConfig {
  id: number;
  key: string;
  tongyi_key: string;
  contact_qr_image: string;
  announcement_enabled: boolean;
  announcement_content: string;
  announcement_updated_at?: string | null;
  updated_at: string;
}

export interface AnnouncementConfig {
  announcement_enabled: boolean;
  announcement_content: string;
  announcement_updated_at?: string | null;
}

export type ExternalApiConfigStatus = "enabled" | "disabled";

export interface ExternalApiConfig {
  id: number;
  name: string;
  description: string;
  group_name: string;
  request_url: string;
  headers_json: string;
  payload_json: string;
  status: ExternalApiConfigStatus;
  created_at: string;
  updated_at?: string;
}

export interface ExternalApiConfigPayload {
  name: string;
  description: string;
  group_name: string;
  request_url: string;
  headers_json: string;
  payload_json: string;
  status: ExternalApiConfigStatus;
}

export interface ExternalApiSceneBinding {
  scene_key: "banana" | "banana2" | "banana_pro" | "banana_pro_plus" | "prompt_reverse" | "inpaint";
  scene_label: string;
  scene_description: string;
  sort_order: number;
  hide_resolution: boolean;
  api_config_id?: number | null;
  api_config_name: string;
  api_group_name: string;
  api_status?: ExternalApiConfigStatus | null;
}

export interface ExternalApiConfigTestResult {
  success: boolean;
  request_url: string;
  status_code?: number | null;
  response_preview: string;
}

export interface GenerationModelOption {
  model_key: string;
  model_label: string;
  model_description: string;
  sort_order: number;
  hide_resolution: boolean;
}
