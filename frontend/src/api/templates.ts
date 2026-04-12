import client from "./client";
import type { CreativeTemplate, TemplateTag } from "@/types";

export interface TemplatePayload {
  prompt: string;
  model: string;
  reference_images: string[];
  num_images: number;
  size: string;
  resolution: string;
  result_image: string;
  tag_names: string[];
}

export function listTemplates(tagId?: number): Promise<CreativeTemplate[]> {
  const params: Record<string, unknown> = {};
  if (tagId) params.tag_id = tagId;
  return client.get("/templates", { params });
}

export function listTemplateTags(): Promise<TemplateTag[]> {
  return client.get("/templates/tags");
}

export function getTemplateDetail(templateId: number): Promise<CreativeTemplate> {
  return client.get(`/templates/${templateId}`);
}

export function listAdminTemplates(): Promise<CreativeTemplate[]> {
  return client.get("/templates/admin/list");
}

export function createTemplate(data: TemplatePayload): Promise<CreativeTemplate> {
  return client.post("/templates", data);
}

export function updateTemplate(templateId: number, data: TemplatePayload): Promise<CreativeTemplate> {
  return client.put(`/templates/${templateId}`, data);
}

export function deleteTemplate(templateId: number): Promise<void> {
  return client.delete(`/templates/${templateId}`);
}
