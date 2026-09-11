export const IMAGE_FILE_ACCEPT_GALLERY = "image/*";
export const IMAGE_FILE_ACCEPT_FILES = "*/*";
export const IMAGE_FILE_ACCEPT_DEFAULT = `${IMAGE_FILE_ACCEPT_GALLERY},${IMAGE_FILE_ACCEPT_FILES}`;

export function isAndroidDevice() {
  if (typeof navigator === "undefined") return false;
  return /Android/i.test(navigator.userAgent);
}
