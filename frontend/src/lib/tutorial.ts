export const TUTORIAL_MODULES = ["generate", "chat", "video", "canvas"] as const;

export type TutorialModule = (typeof TUTORIAL_MODULES)[number];

export const DEFAULT_TUTORIAL_MODULE: TutorialModule = "generate";

export const tutorialModuleMeta: Record<
  TutorialModule,
  { label: string; path: string; doc: string; placeholder?: boolean }
> = {
  generate: {
    label: "AI 生图",
    path: "/tutorial/generate",
    doc: "docs/generate-tutorial.html",
  },
  chat: {
    label: "AI 对话",
    path: "/tutorial/chat",
    doc: "docs/chat-tutorial.html",
    placeholder: true,
  },
  video: {
    label: "AI 视频",
    path: "/tutorial/video",
    doc: "docs/video-tutorial.html",
    placeholder: true,
  },
  canvas: {
    label: "无限画布",
    path: "/tutorial/canvas",
    doc: "docs/canvas-tutorial.html",
    placeholder: true,
  },
};

export const tutorialNavOrder: TutorialModule[] = ["chat", "generate", "video", "canvas"];

export const generateTutorialSections = [
  { id: "overview", label: "1. 进入页面与布局" },
  { id: "modes", label: "2. 选择创作模式" },
  { id: "text-generate", label: "3. 文生图" },
  { id: "image-edit", label: "4. 图编辑" },
  { id: "inpaint", label: "5. 局部重绘" },
  { id: "prompt-reverse", label: "6. 提示词反推" },
  { id: "prompt-tools", label: "7. 提示词工具" },
  { id: "model-params", label: "8. 模型与参数" },
  { id: "submit", label: "9. 开始生成" },
  { id: "results", label: "10. 查看与处理结果" },
  { id: "assets-boards", label: "11. 素材、看板与历史" },
  { id: "batch", label: "12. 批量生图" },
  { id: "assistant", label: "13. AI 助手联动" },
  { id: "tips", label: "14. 使用建议" },
] as const;

export function isTutorialModule(value: string | undefined): value is TutorialModule {
  return TUTORIAL_MODULES.includes(value as TutorialModule);
}

export function resolveTutorialModule(value: string | undefined): TutorialModule {
  return isTutorialModule(value) ? value : DEFAULT_TUTORIAL_MODULE;
}
