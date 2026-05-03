export const APP_THEME_STORAGE_KEY = "banana-web-theme";
export const APP_THEME_ATTRIBUTE = "data-theme";

export const appThemes = {
  warm: {
    key: "warm",
    label: "暖色主题",
  },
  dark: {
    key: "dark",
    label: "黑色主题",
  },
} as const;

export type AppThemeName = keyof typeof appThemes;

export const DEFAULT_APP_THEME: AppThemeName = "dark";

export function isAppThemeName(value: string | null | undefined): value is AppThemeName {
  return value === "warm" || value === "dark";
}
