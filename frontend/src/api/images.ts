import client from "./client";
import type { ImageResult } from "@/types";

export function regenerateImage(imageId: number): Promise<any> {
  return client.post(`/images/${imageId}/regenerate`);
}

export function deleteImage(imageId: number): Promise<void> {
  return client.delete(`/images/${imageId}`);
}

export function resolveImageUrl(imageUrl?: string): string {
  if (!imageUrl) return "";
  if (/^(https?:)?\/\//.test(imageUrl) || imageUrl.startsWith("data:") || imageUrl.startsWith("blob:")) {
    return imageUrl;
  }
  const base = import.meta.env.VITE_API_BASE_URL || "";
  return `${base}${imageUrl.startsWith("/") ? imageUrl : `/${imageUrl}`}`;
}

export function getDisplayImageUrl(image?: Pick<ImageResult, "thumb_url" | "image_url" | "preview_url">): string {
  return resolveImageUrl(image?.thumb_url || image?.image_url || image?.preview_url || "");
}

export function getPreviewImageUrl(image?: Pick<ImageResult, "image_url" | "preview_url" | "thumb_url">): string {
  return resolveImageUrl(image?.image_url || image?.preview_url || image?.thumb_url || "");
}

function buildDownloadFilename(imageId: number, imageUrl: string): string {
  const cleanPath = imageUrl.split("?")[0] || "";
  const suffix = cleanPath.includes(".") ? cleanPath.slice(cleanPath.lastIndexOf(".")) : ".png";
  return `banana_${imageId}${suffix || ".png"}`;
}

export function getDownloadUrl(imageId: number, imageUrl?: string, previewUrl?: string): string {
  if (imageUrl && /^https?:\/\//.test(imageUrl)) {
    return imageUrl;
  }
  if (!imageUrl && previewUrl) {
    return resolveImageUrl(previewUrl);
  }
  const base = import.meta.env.VITE_API_BASE_URL || "";
  return `${base}/api/images/${imageId}/download`;
}
