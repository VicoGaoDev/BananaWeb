import client from "./client";
import type { Style, StylePrompt } from "@/types";

export function fetchStyles(): Promise<Style[]> {
  return client.get("/styles");
}

export function createStyle(data: { name: string; cover_image?: string; description?: string }): Promise<Style> {
  return client.post("/styles", data);
}

export function deleteStyle(styleId: number): Promise<any> {
  return client.delete(`/styles/${styleId}`);
}

export function fetchPrompts(styleId: number): Promise<StylePrompt[]> {
  return client.get(`/styles/${styleId}/prompts`);
}

export function addPrompt(styleId: number, data: { prompt: string; negative_prompt?: string; sort_order?: number }): Promise<StylePrompt> {
  return client.post(`/styles/${styleId}/prompts`, data);
}

export function updatePrompt(
  styleId: number,
  promptId: number,
  data: { prompt: string; negative_prompt?: string; sort_order?: number },
): Promise<StylePrompt> {
  return client.put(`/styles/${styleId}/prompts/${promptId}`, data);
}

export function deletePrompt(styleId: number, promptId: number): Promise<any> {
  return client.delete(`/styles/${styleId}/prompts/${promptId}`);
}
