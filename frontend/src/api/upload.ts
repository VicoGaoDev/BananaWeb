import client from "./client";

export function uploadReferenceImage(file: File): Promise<{ url: string }> {
  const form = new FormData();
  form.append("file", file);
  return client.post("/upload", form, {
    headers: { "Content-Type": "multipart/form-data" },
  });
}
