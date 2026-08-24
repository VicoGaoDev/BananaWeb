import generateStylesData from "@/config/generate-styles.json";

export type GenerateStyleCategoryId = "color" | "lighting";
export type GenerateStylePreviewPattern = "soft" | "rim" | "top" | "bottom" | "silhouette" | "hard" | "blinds";

export interface GenerateStylePreview {
  from: string;
  to: string;
  via?: string;
  pattern?: GenerateStylePreviewPattern;
}

export interface GenerateStyleItem {
  id: string;
  name: string;
  prompt: string;
  thumbnail?: string;
  preview: GenerateStylePreview;
}

export interface GenerateStyleCategory {
  id: GenerateStyleCategoryId;
  name: string;
  items: GenerateStyleItem[];
}

interface GenerateStylesCatalog {
  version: number;
  categories: GenerateStyleCategory[];
}

const catalog = generateStylesData as GenerateStylesCatalog;

export const generateStyleCategories: GenerateStyleCategory[] = catalog.categories || [];

const styleMap = new Map<string, GenerateStyleItem>();
for (const category of generateStyleCategories) {
  for (const item of category.items) {
    styleMap.set(item.id, item);
  }
}

export function getGenerateStyleCategory(categoryId: GenerateStyleCategoryId): GenerateStyleCategory | undefined {
  return generateStyleCategories.find((item) => item.id === categoryId);
}

export function getGenerateStyleById(styleId?: string | null): GenerateStyleItem | undefined {
  const normalized = (styleId || "").trim();
  if (!normalized) return undefined;
  return styleMap.get(normalized);
}

export function composeGeneratePrompt(
  userPrompt: string,
  colorStyleId?: string | null,
  lightingStyleId?: string | null,
): string {
  const parts = [(userPrompt || "").trim()].filter(Boolean);
  const colorStyle = getGenerateStyleById(colorStyleId);
  const lightingStyle = getGenerateStyleById(lightingStyleId);
  if (colorStyle?.prompt) parts.push(colorStyle.prompt.trim());
  if (lightingStyle?.prompt) parts.push(lightingStyle.prompt.trim());
  return parts.join("\n\n");
}

export function formatSelectedGenerateStyleLabel(
  colorStyleId?: string | null,
  lightingStyleId?: string | null,
): string {
  const names = [
    getGenerateStyleById(colorStyleId)?.name,
    getGenerateStyleById(lightingStyleId)?.name,
  ].filter(Boolean);
  return names.join(" · ");
}
