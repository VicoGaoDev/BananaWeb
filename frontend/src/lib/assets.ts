export function withBaseUrl(path: string): string {
  if (!path) return path;
  if (/^(?:[a-z]+:)?\/\//i.test(path)) return path;

  const baseUrl = import.meta.env.BASE_URL.endsWith("/")
    ? import.meta.env.BASE_URL
    : `${import.meta.env.BASE_URL}/`;

  return `${baseUrl}${path.replace(/^\/+/, "")}`;
}
