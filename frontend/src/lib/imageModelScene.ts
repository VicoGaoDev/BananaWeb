export type ImageModelSceneMark = "generate" | "image_edit" | "";

export interface ImageModelFilterOption {
  value: string;
  label: string;
  sceneType: ImageModelSceneMark;
}

const UNMARKED_SCENE_KEYS = new Set(["inpaint", "smart_cutout", "prompt_reverse", "提示词反推"]);

export function imageModelSceneMark(sceneType?: string | null, sceneKey?: string | null): ImageModelSceneMark {
  if (sceneKey && UNMARKED_SCENE_KEYS.has(sceneKey)) return "";
  if (sceneType === "image_edit") return "image_edit";
  if (sceneType === "generate") return "generate";
  return "";
}

export interface ImageModelFilterGroup {
  label: string;
  options: ImageModelFilterOption[];
}

export function groupImageModelFilterOptions(options: ImageModelFilterOption[]) {
  const generate = options.filter((item) => item.sceneType === "generate");
  const imageEdit = options.filter((item) => item.sceneType === "image_edit");
  const others = options.filter((item) => item.sceneType !== "generate" && item.sceneType !== "image_edit");
  const groups: ImageModelFilterGroup[] = [];
  if (generate.length) groups.push({ label: "文生图", options: generate });
  if (imageEdit.length) groups.push({ label: "图编辑", options: imageEdit });
  if (others.length && groups.length) groups.push({ label: "其他", options: others });
  return {
    groups,
    flatOptions: groups.length ? [] : others,
  };
}

export function buildMixedImageModelFilterOptions(input: {
  generationModels?: Array<{ model_key: string; model_label: string }>;
  scenes?: Array<{ scene_key: string; scene_type: string; display_name?: string; scene_label?: string }>;
  extras?: Array<{ value: string; label: string }>;
}): ImageModelFilterOption[] {
  const optionMap = new Map<string, ImageModelFilterOption>();
  input.generationModels?.forEach((item) => {
    optionMap.set(item.model_key, {
      value: item.model_key,
      label: item.model_label,
      sceneType: imageModelSceneMark("generate", item.model_key),
    });
  });
  input.scenes
    ?.filter((item) => item.scene_type === "image_edit")
    .forEach((item) => {
      optionMap.set(item.scene_key, {
        value: item.scene_key,
        label: item.display_name || item.scene_label || item.scene_key,
        sceneType: imageModelSceneMark(item.scene_type, item.scene_key),
      });
    });
  input.extras?.forEach((item) => {
    if (optionMap.has(item.value)) return;
    optionMap.set(item.value, {
      value: item.value,
      label: item.label,
      sceneType: imageModelSceneMark("", item.value),
    });
  });
  return Array.from(optionMap.values());
}
