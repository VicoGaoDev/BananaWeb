import client from "./client";

export function regenerateImage(imageId: number): Promise<any> {
  return client.post(`/images/${imageId}/regenerate`);
}

export function deleteImage(imageId: number): Promise<void> {
  return client.delete(`/images/${imageId}`);
}

function buildDownloadFilename(imageId: number, imageUrl: string): string {
  const cleanPath = imageUrl.split("?")[0] || "";
  const suffix = cleanPath.includes(".") ? cleanPath.slice(cleanPath.lastIndexOf(".")) : ".png";
  return `banana_${imageId}${suffix || ".png"}`;
}

export function getDownloadUrl(imageId: number, imageUrl?: string): string {
  if (imageUrl && /^https?:\/\//.test(imageUrl)) {
    return imageUrl;
  }
  const base = import.meta.env.VITE_API_BASE_URL || "";
  return `${base}/api/images/${imageId}/download`;
}
