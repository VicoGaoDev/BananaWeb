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
  preview_url?: string;
  thumb_url?: string;
  status: "pending" | "success" | "failed";
  error_message?: string;
  image_format?: string;
  image_size_bytes?: number;
  is_deleted?: boolean;
}

export interface TaskResult {
  id: number;
  model: string;
  prompt: string;
  num_images: number;
  size: string;
  resolution: string;
  status: "pending" | "processing" | "success" | "failed";
  error_message?: string;
  created_at: string;
  images: ImageResult[];
}

export interface HistoryItem {
  task_id: number;
  username?: string;
  avatar_url?: string;
  model: string;
  mode: "generate" | "inpaint";
  prompt: string;
  reference_images: string[];
  num_images: number;
  size: string;
  resolution: string;
  status: string;
  error_message?: string;
  is_soft_deleted?: boolean;
  soft_deleted_count?: number;
  created_at: string;
  images: ImageResult[];
}

export interface HistoryFilter {
  mode?: "generate" | "inpaint";
  model?: string;
  prompt?: string;
  status?: string;
  user_id?: number;
  start_date?: string;
  end_date?: string;
}

export interface HistoryResponse {
  total: number;
  items: HistoryItem[];
}

export interface UserHistoryCard {
  task_id: number;
  image_id: number;
  image_url: string;
  preview_url?: string;
  thumb_url?: string;
  status: "pending" | "processing" | "success" | "failed";
  image_format?: string;
  image_size_bytes?: number;
  is_soft_deleted?: boolean;
  model: string;
  mode: "generate" | "inpaint";
  prompt: string;
  reference_images: string[];
  reference_image_thumbs: string[];
  source_image: string;
  source_image_thumb: string;
  num_images: number;
  size: string;
  resolution: string;
  created_at: string;
  error_message?: string;
  images: ImageResult[];
}

export interface UserHistoryResponse {
  total: number;
  items: UserHistoryCard[];
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
  template_count?: number;
}

export interface CreativeTemplate {
  id: number;
  prompt: string;
  model: string;
  reference_images: string[];
  reference_image_thumbs?: string[];
  num_images: number;
  size: string;
  resolution: string;
  result_image: string;
  result_image_thumb?: string;
  sort_order: number;
  tags: TemplateTag[];
  created_at: string;
}

export interface AdminStats {
  last_7_days: number;
  last_30_days: number;
  total_users: number;
  active_users: number;
}

export interface AdminConfig {
  id: number;
  contact_qr_image: string;
  announcement_enabled: boolean;
  announcement_content: string;
  announcement_updated_at?: string | null;
  updated_at: string;
}

export interface ExternalApiSecretConfig {
  id: number;
  key: string;
  tongyi_key: string;
  updated_at?: string | null;
}

export interface CosConfig {
  id: number;
  cos_secret_id: string;
  cos_secret_key: string;
  cos_bucket: string;
  cos_region: string;
  cos_public_base_url: string;
  updated_at?: string | null;
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
  display_name: string;
  subtitle: string;
  sort_order: number;
  hide_resolution: boolean;
  api_config_id?: number | null;
  api_config_name: string;
  api_group_name: string;
  api_status?: ExternalApiConfigStatus | null;
  credit_cost: number;
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
  display_name: string;
  subtitle: string;
  sort_order: number;
  hide_resolution: boolean;
  credit_cost: number;
}

export interface TaskSceneConfig {
  scene_key: "banana" | "banana2" | "banana_pro" | "banana_pro_plus" | "prompt_reverse" | "inpaint";
  scene_label: string;
  scene_description: string;
  display_name: string;
  subtitle: string;
  sort_order: number;
  hide_resolution: boolean;
  credit_cost: number;
}

export type UploadPurpose = "ref" | "source" | "mask" | "reverse" | "misc" | "template";

export interface UploadCredential {
  bucket: string;
  region: string;
  key: string;
  url: string;
  tmp_secret_id: string;
  tmp_secret_key: string;
  session_token: string;
  start_time?: number | null;
  expired_time: number;
}
