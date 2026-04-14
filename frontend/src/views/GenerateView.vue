<script setup lang="ts">
import { ref, computed, h, inject, onBeforeUnmount, onMounted, type Ref } from "vue";
import { message } from "ant-design-vue";
import {
  CloseOutlined,
  CloudUploadOutlined,
  ClockCircleOutlined,
  ClearOutlined,
  CopyOutlined,
  DeleteOutlined,
  DownloadOutlined,
  EditOutlined,
  EyeOutlined,
  LoadingOutlined,
  PictureOutlined,
  RedoOutlined,
  ReloadOutlined,
  ThunderboltOutlined,
  UndoOutlined,
} from "@ant-design/icons-vue";
import { getGenerationModels, getTaskScenes } from "@/api/config";
import { createTask, getTask } from "@/api/tasks";
import { getDownloadUrl, regenerateImage, resolveImageUrl } from "@/api/images";
import { reversePrompt } from "@/api/promptReverse";
import { uploadReferenceImage } from "@/api/upload";
import { getMe, getPromptHistory, deletePromptHistory } from "@/api/auth";
import { usePolling } from "@/composables/usePolling";
import { useAuthStore } from "@/stores/auth";
import RepaintCanvas from "@/components/generate/RepaintCanvas.vue";
import type { GenerationModelOption, ImageResult, TaskResult, TaskSceneConfig } from "@/types";

const auth = useAuthStore();
const loginModalVisible = inject<Ref<boolean>>("loginModalVisible")!;

type GenerateMode = "generate" | "inpaint" | "promptReverse";
const DEFAULT_SCENE_COSTS: Record<string, number> = {
  banana: 4,
  banana2: 4,
  banana_pro: 4,
  banana_pro_plus: 4,
  prompt_reverse: 1,
  inpaint: 4,
};

const generateMode = ref<GenerateMode>("generate");
const prompt = ref("");
const repaintPrompt = ref("");
const selectedModel = ref("banana_pro");
const numImages = ref(1);
const resolution = ref("2K");
const size = ref("9:16");
const loading = ref(false);
const images = ref<ImageResult[]>([]);
const currentTaskId = ref<number | null>(null);

type UploadItemStatus = "uploading" | "success" | "failed";

interface UploadPreviewItem {
  id: string;
  localUrl: string;
  remoteUrl: string;
  status: UploadItemStatus;
  objectUrl?: string;
}

const MAX_REFS = 6;
const referenceItems = ref<UploadPreviewItem[]>([]);
const fileInput = ref<HTMLInputElement | null>(null);
const sourceImageUrl = ref("");
const sourcePreviewUrl = ref("");
const sourceUploading = ref(false);
const sourceInput = ref<HTMLInputElement | null>(null);
const reverseImageUrl = ref("");
const reverseUploading = ref(false);
const reverseInput = ref<HTMLInputElement | null>(null);
const reverseLoading = ref(false);
const reversePromptResult = ref("");
const brushSize = ref(28);
const repaintTool = ref<"paint" | "erase">("paint");
const hasRepaintMask = ref(false);
const canUndoMask = ref(false);
const canRedoMask = ref(false);
const repaintCanvasRef = ref<{
  clearMask: () => void;
  hasDrawnMask: () => boolean;
  exportMaskBlob: () => Promise<Blob | null>;
  undo: () => boolean;
  canUndo: () => boolean;
  redo: () => boolean;
  canRedo: () => boolean;
} | null>(null);

const previewVisible = ref(false);
const previewCurrent = ref("");

const historyVisible = ref(false);
const historyItems = ref<{ id: number; prompt: string; created_at: string }[]>([]);
const historyLoading = ref(false);
const HISTORY_DRAFT_KEY = "generateDraftFromHistory";
const TEMPLATE_DRAFT_KEY = "generateDraftFromTemplate";
const generationModels = ref<GenerationModelOption[]>([]);
const taskScenes = ref<TaskSceneConfig[]>([]);

const resolutionOptions = [
  { label: "1K", value: "1K" },
  { label: "2K", value: "2K" },
  { label: "4K", value: "4K" },
];

const sizeOptions = [
  { label: "■  1:1", value: "1:1" },
  { label: "▮  2:3", value: "2:3" },
  { label: "▬  3:2", value: "3:2" },
  { label: "▮  3:4", value: "3:4" },
  { label: "▬  4:3", value: "4:3" },
  { label: "▮  9:16", value: "9:16" },
  { label: "▬  16:9", value: "16:9" },
];

const pendingCount = computed(() => images.value.filter((img) => img.status === "pending").length);
const resultEmptyTitle = computed(() => (
  generateMode.value === "promptReverse" ? "提示词反推结果会在左侧展示" : "生图结果将在这里展示"
));
const resultEmptyDesc = computed(() => (
  generateMode.value === "promptReverse"
    ? "上传图片后点击「开始反推」，即可得到适合 AI 绘画的中文提示词"
    : "在左侧设置提示词和参数，点击「开始生成」即可"
));
const resultLayoutClass = computed(() => ({
  "result-list-single": images.value.length === 1,
  "result-list-double": images.value.length >= 2,
}));
const referenceUrls = computed(() => (
  referenceItems.value
    .filter((item) => item.status === "success" && item.remoteUrl)
    .map((item) => item.remoteUrl)
));
const uploading = computed(() => referenceItems.value.some((item) => item.status === "uploading"));
const hasPendingReferenceUploads = computed(() => referenceItems.value.some((item) => item.status === "uploading"));
const hasFailedReferenceUploads = computed(() => referenceItems.value.some((item) => item.status === "failed"));
const sourceDisplayUrl = computed(() => resolveImageUrl(sourcePreviewUrl.value || sourceImageUrl.value));
const hasBlockedUploads = computed(() => {
  if (generateMode.value === "inpaint") {
    return !!sourcePreviewUrl.value && !sourceImageUrl.value;
  }
  return hasPendingReferenceUploads.value || hasFailedReferenceUploads.value;
});
const selectedModelOption = computed(
  () => generationModels.value.find((item) => item.model_key === selectedModel.value) || null
);
const hideResolution = computed(() => generateMode.value === "generate" && !!selectedModelOption.value?.hide_resolution);
const sceneCostMap = computed(() => Object.fromEntries(taskScenes.value.map((item) => [item.scene_key, item.credit_cost])));
const selectedModelCreditCost = computed(() => (
  selectedModelOption.value?.credit_cost
  ?? sceneCostMap.value[selectedModel.value]
  ?? DEFAULT_SCENE_COSTS[selectedModel.value]
  ?? 0
));
const promptReverseCreditCost = computed(() => sceneCostMap.value.prompt_reverse ?? DEFAULT_SCENE_COSTS.prompt_reverse);
const inpaintCreditCost = computed(() => sceneCostMap.value.inpaint ?? DEFAULT_SCENE_COSTS.inpaint);

const polling = usePolling<TaskResult>(
  () => getTask(currentTaskId.value!),
  {
    interval: 2000,
    shouldStop: (data) => data.status === "success" || data.status === "failed",
    onResult: (data) => {
      images.value = data.images;
      if (data.status === "success" || data.status === "failed") {
        loading.value = false;
        data.status === "success"
          ? message.success("图片生成完成！")
          : message.warning("部分图片生成失败");
      }
    },
  }
);

async function ensureAuthenticated() {
  if (!auth.isLoggedIn) {
    loginModalVisible.value = true;
    return false;
  }
  try {
    auth.updateUser(await getMe());
    return true;
  } catch {
    loginModalVisible.value = true;
    return false;
  }
}

async function triggerUpload() {
  if (!(await ensureAuthenticated())) return;
  fileInput.value?.click();
}

function revokeObjectUrl(url?: string) {
  if (url?.startsWith("blob:")) URL.revokeObjectURL(url);
}

function syncReferenceItems(urls: string[]) {
  referenceItems.value.forEach((item) => revokeObjectUrl(item.objectUrl));
  referenceItems.value = urls.map((url, index) => ({
    id: `${Date.now()}-${index}-${url}`,
    localUrl: url,
    remoteUrl: url,
    status: "success",
  }));
}

function getReferencePreviewUrl(item: UploadPreviewItem) {
  return resolveImageUrl(item.localUrl || item.remoteUrl);
}

function updateReferenceItem(id: string, patch: Partial<UploadPreviewItem>) {
  const index = referenceItems.value.findIndex((item) => item.id === id);
  if (index === -1) return;
  referenceItems.value[index] = {
    ...referenceItems.value[index],
    ...patch,
  };
}

async function handleFileChange(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;

  if (referenceItems.value.length >= MAX_REFS) {
    message.warning(`最多上传 ${MAX_REFS} 张参考图`);
    input.value = "";
    return;
  }

  if (file.size > 10 * 1024 * 1024) {
    message.warning("图片大小不能超过 10MB");
    input.value = "";
    return;
  }

  const objectUrl = URL.createObjectURL(file);
  const item: UploadPreviewItem = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    localUrl: objectUrl,
    remoteUrl: "",
    status: "uploading",
    objectUrl,
  };
  referenceItems.value.push(item);
  try {
    const res = await uploadReferenceImage(file, "ref");
    revokeObjectUrl(objectUrl);
    updateReferenceItem(item.id, {
      objectUrl: undefined,
      localUrl: res.url,
      remoteUrl: res.url,
      status: "success",
    });
    message.success("参考图上传成功");
  } catch {
    updateReferenceItem(item.id, { status: "failed" });
    message.error("上传失败，请重试");
  } finally {
    input.value = "";
  }
}

function removeReference(index: number) {
  const item = referenceItems.value[index];
  if (item) revokeObjectUrl(item.objectUrl);
  referenceItems.value.splice(index, 1);
}

async function triggerSourceUpload() {
  if (!(await ensureAuthenticated())) return;
  sourceInput.value?.click();
}

async function handleSourceFileChange(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;

  if (file.size > 10 * 1024 * 1024) {
    message.warning("图片大小不能超过 10MB");
    input.value = "";
    return;
  }

  revokeObjectUrl(sourcePreviewUrl.value);
  sourcePreviewUrl.value = URL.createObjectURL(file);
  sourceImageUrl.value = "";
  sourceUploading.value = true;
  try {
    const res = await uploadReferenceImage(file, "source");
    sourceImageUrl.value = res.url;
    hasRepaintMask.value = false;
    repaintCanvasRef.value?.clearMask();
    message.success("原图上传成功");
  } catch {
    message.error("原图上传失败，请重试");
  } finally {
    sourceUploading.value = false;
    input.value = "";
  }
}

function removeSourceImage() {
  revokeObjectUrl(sourcePreviewUrl.value);
  sourcePreviewUrl.value = "";
  sourceImageUrl.value = "";
  hasRepaintMask.value = false;
  canUndoMask.value = false;
  canRedoMask.value = false;
}

async function triggerReverseUpload() {
  if (!(await ensureAuthenticated())) return;
  reverseInput.value?.click();
}

async function handleReverseFileChange(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;

  if (file.size > 10 * 1024 * 1024) {
    message.warning("图片大小不能超过 10MB");
    input.value = "";
    return;
  }

  reverseUploading.value = true;
  try {
    const res = await uploadReferenceImage(file, "reverse");
    reverseImageUrl.value = res.url;
    reversePromptResult.value = "";
    message.success("反推图片上传成功");
  } catch {
    message.error("图片上传失败，请重试");
  } finally {
    reverseUploading.value = false;
    input.value = "";
  }
}

function removeReverseImage() {
  reverseImageUrl.value = "";
  reversePromptResult.value = "";
}

function clearRepaintMask() {
  repaintCanvasRef.value?.clearMask();
  hasRepaintMask.value = false;
  canUndoMask.value = false;
  canRedoMask.value = false;
}

function undoRepaintMask() {
  const changed = repaintCanvasRef.value?.undo();
  if (!changed) return;
  hasRepaintMask.value = repaintCanvasRef.value?.hasDrawnMask() ?? false;
  canUndoMask.value = repaintCanvasRef.value?.canUndo() ?? false;
  canRedoMask.value = repaintCanvasRef.value?.canRedo() ?? false;
}

function redoRepaintMask() {
  const changed = repaintCanvasRef.value?.redo();
  if (!changed) return;
  hasRepaintMask.value = repaintCanvasRef.value?.hasDrawnMask() ?? false;
  canUndoMask.value = repaintCanvasRef.value?.canUndo() ?? false;
  canRedoMask.value = repaintCanvasRef.value?.canRedo() ?? false;
}

function handleMaskChange(value: boolean) {
  hasRepaintMask.value = value;
  canUndoMask.value = repaintCanvasRef.value?.canUndo() ?? false;
  canRedoMask.value = repaintCanvasRef.value?.canRedo() ?? false;
}

const creditCost = computed(() => (
  generateMode.value === "inpaint"
    ? inpaintCreditCost.value
    : numImages.value * selectedModelCreditCost.value
));
const userCredits = computed(() => auth.user?.credits ?? 0);
const isSuperAdmin = computed(() => auth.isSuperAdmin);
const generateButtonText = computed(() => {
  if (loading.value) {
    return generateMode.value === "inpaint" ? "AI 局部重绘中..." : "AI 绘制中...";
  }
  if (generateMode.value === "inpaint" && sourceUploading.value) {
    return "原图上传中...";
  }
  if (generateMode.value === "inpaint" && sourcePreviewUrl.value && !sourceImageUrl.value) {
    return "原图未上传完成";
  }
  if (generateMode.value === "generate" && hasPendingReferenceUploads.value) {
    return "参考图上传中...";
  }
  if (generateMode.value === "generate" && hasFailedReferenceUploads.value) {
    return "参考图上传失败，请处理后再生成";
  }
  return isSuperAdmin.value ? "开始生成" : `开始生成 · ${creditCost.value} 积分`;
});
const promptReverseButtonText = computed(() => {
  if (reverseLoading.value) return "提示词反推中...";
  return isSuperAdmin.value ? "开始反推" : `开始反推 · ${promptReverseCreditCost.value} 积分`;
});
const activePrompt = computed(() => (
  generateMode.value === "inpaint" ? repaintPrompt.value : prompt.value
));

async function handlePromptReverse() {
  if (!(await ensureAuthenticated())) return;
  if (!reverseImageUrl.value.trim()) {
    message.warning("请先上传需要反推提示词的图片");
    return;
  }
  if (!isSuperAdmin.value && userCredits.value < promptReverseCreditCost.value) {
    message.warning(`积分不足，需要 ${promptReverseCreditCost.value} 积分，当前余额 ${userCredits.value}`);
    return;
  }

  reverseLoading.value = true;
  try {
    const res = await reversePrompt(reverseImageUrl.value);
    reversePromptResult.value = res.prompt;
    message.success("提示词反推完成");
    getMe().then((u) => auth.updateUser(u)).catch(() => {});
  } catch (err: any) {
    message.error(err.response?.data?.detail || "提示词反推失败");
  } finally {
    reverseLoading.value = false;
  }
}

function copyReversePrompt() {
  if (!reversePromptResult.value.trim()) return;
  navigator.clipboard.writeText(reversePromptResult.value).then(() => {
    message.success("已复制提示词");
  });
}

function applyReversePrompt() {
  if (!reversePromptResult.value.trim()) return;
  prompt.value = reversePromptResult.value;
  generateMode.value = "generate";
  message.success("已带入到文生图/图编辑");
}

async function handleGenerate() {
  if (!(await ensureAuthenticated())) return;
  if (!activePrompt.value.trim()) {
    message.warning("请输入提示词");
    return;
  }
  if (generateMode.value === "generate" && hasPendingReferenceUploads.value) {
    message.warning("参考图仍在上传中，请稍候再发起任务");
    return;
  }
  if (generateMode.value === "generate" && hasFailedReferenceUploads.value) {
    message.warning("存在上传失败的参考图，请删除或重新上传后再试");
    return;
  }
  if (!isSuperAdmin.value && userCredits.value < creditCost.value) {
    message.warning(`积分不足，需要 ${creditCost.value} 积分，当前余额 ${userCredits.value}`);
    return;
  }

  let payload: {
    model?: string;
    prompt: string;
    num_images: number;
    size: string;
    resolution: string;
    mode?: "generate" | "inpaint";
    reference_images?: string[];
    source_image?: string;
    mask_image?: string;
  };

  if (generateMode.value === "inpaint") {
    if (!sourceImageUrl.value.trim()) {
      message.warning(sourceUploading.value ? "原图上传中，请稍候再试" : "请先上传需要局部重绘的原图");
      return;
    }
    if (!hasRepaintMask.value || !repaintCanvasRef.value?.hasDrawnMask()) {
      message.warning("请先在原图上涂抹需要重绘的区域");
      return;
    }
    const maskBlob = await repaintCanvasRef.value.exportMaskBlob();
    if (!maskBlob) {
      message.warning("蒙版生成失败，请重新涂抹后再试");
      return;
    }
    const maskFile = new File([maskBlob], `mask-${Date.now()}.png`, { type: "image/png" });
    let maskUploadUrl = "";
    try {
      const uploaded = await uploadReferenceImage(maskFile, "mask");
      maskUploadUrl = uploaded.url;
    } catch {
      message.error("蒙版上传失败，请重试");
      return;
    }
    payload = {
      mode: "inpaint",
      prompt: repaintPrompt.value,
      num_images: 1,
      size: size.value,
      resolution: resolution.value,
      source_image: sourceImageUrl.value,
      mask_image: maskUploadUrl,
    };
  } else {
    payload = {
      mode: "generate",
      model: selectedModel.value,
      prompt: prompt.value,
      num_images: numImages.value,
      size: size.value,
      resolution: hideResolution.value ? "" : resolution.value,
      reference_images: referenceUrls.value.length ? referenceUrls.value : undefined,
    };
  }

  loading.value = true;
  images.value = [];
  try {
    const res = await createTask(payload);
    currentTaskId.value = res.task_id;
    const taskData = await getTask(res.task_id);
    images.value = taskData.images;
    polling.start();
    getMe().then((u) => auth.updateUser(u)).catch(() => {});
  } catch (err: any) {
    loading.value = false;
    message.error(err.response?.data?.detail || "创建任务失败");
  }
}

async function handleRegenerate(imageId: number) {
  try {
    await regenerateImage(imageId);
    message.success("已提交重新生成");
    if (currentTaskId.value) {
      const taskData = await getTask(currentTaskId.value);
      images.value = taskData.images;
      if (taskData.images.some((img) => img.status === "pending")) polling.start();
    }
  } catch (err: any) {
    message.error(err.response?.data?.detail || "重新生成失败");
  }
}

function handlePreview(url: string) {
  previewCurrent.value = url;
  previewVisible.value = true;
}

function getResultDisplayUrl(img: ImageResult) {
  return resolveImageUrl(img.image_url || img.preview_url || "");
}

function handleDownload(imageId: number, imageUrl: string, previewUrl?: string) {
  const a = document.createElement("a");
  a.href = getDownloadUrl(imageId, imageUrl, previewUrl);
  a.download = `banana_${imageId}.png`;
  a.click();
}

async function openHistory() {
  if (!(await ensureAuthenticated())) return;
  historyVisible.value = true;
  historyLoading.value = true;
  try {
    historyItems.value = await getPromptHistory();
  } catch {
    message.error("获取历史提示词失败");
  } finally {
    historyLoading.value = false;
  }
}

async function removeHistoryItem(id: number) {
  try {
    await deletePromptHistory(id);
    historyItems.value = historyItems.value.filter((i) => i.id !== id);
  } catch {
    message.error("删除失败");
  }
}

function useHistoryPrompt(text: string) {
  prompt.value = text;
  historyVisible.value = false;
}

function applyDraft(raw: string | null, successText: string, storageKey: string) {
  if (!raw) return;
  try {
    const draft = JSON.parse(raw) as {
      mode?: "generate" | "inpaint";
      prompt?: string;
      model?: string;
      reference_images?: string[];
      num_images?: number;
      size?: string;
      resolution?: string;
      source_image?: string;
    };
    const draftMode = draft.mode === "inpaint" ? "inpaint" : "generate";
    generateMode.value = draftMode;
    size.value = draft.size || "9:16";
    resolution.value = draft.resolution || "2K";

    if (draftMode === "inpaint") {
      repaintPrompt.value = draft.prompt || "";
      revokeObjectUrl(sourcePreviewUrl.value);
      sourceImageUrl.value = draft.source_image || "";
      sourcePreviewUrl.value = "";
      hasRepaintMask.value = false;
      canUndoMask.value = false;
      canRedoMask.value = false;
      repaintCanvasRef.value?.clearMask();
      prompt.value = "";
      syncReferenceItems([]);
      numImages.value = 1;
    } else {
      prompt.value = draft.prompt || "";
      selectedModel.value = draft.model || selectedModel.value;
      syncReferenceItems(Array.isArray(draft.reference_images) ? draft.reference_images.slice(0, MAX_REFS) : []);
      numImages.value = Math.min(4, Math.max(1, Number(draft.num_images || 1)));
      repaintPrompt.value = "";
      revokeObjectUrl(sourcePreviewUrl.value);
      sourcePreviewUrl.value = "";
      sourceImageUrl.value = "";
      hasRepaintMask.value = false;
      canUndoMask.value = false;
      canRedoMask.value = false;
      repaintCanvasRef.value?.clearMask();
    }
    localStorage.removeItem(storageKey);
    message.success(successText);
  } catch {
    localStorage.removeItem(storageKey);
  }
}

async function loadGenerationModelOptions() {
  try {
    generationModels.value = await getGenerationModels();
    if (!generationModels.value.length) return;
    if (!generationModels.value.some((item) => item.model_key === selectedModel.value)) {
      selectedModel.value = generationModels.value[0].model_key;
    }
  } catch {
    // ignore model loading failures, backend will still validate on submit
  }
}

async function loadTaskSceneConfigs() {
  try {
    taskScenes.value = await getTaskScenes();
  } catch {
    // ignore scene config loading failures, backend will still validate on submit
  }
}

onMounted(async () => {
  await Promise.all([loadGenerationModelOptions(), loadTaskSceneConfigs()]);
  applyDraft(
    localStorage.getItem(HISTORY_DRAFT_KEY),
    "已回填历史任务参数，可继续编辑后重新生成",
    HISTORY_DRAFT_KEY
  );
  applyDraft(
    localStorage.getItem(TEMPLATE_DRAFT_KEY),
    "已套用创意模版参数，可继续编辑后生成",
    TEMPLATE_DRAFT_KEY
  );
});

onBeforeUnmount(() => {
  referenceItems.value.forEach((item) => revokeObjectUrl(item.objectUrl));
  revokeObjectUrl(sourcePreviewUrl.value);
});
</script>

<template>
  <div class="generate-page">
    <div class="generate-workbench">
      <div class="left-col">
        <a-tabs v-model:activeKey="generateMode" class="generate-tabs">
          <a-tab-pane key="generate" tab="文生图/图编辑">
            <section class="work-panel settings-panel">
              <div class="settings-row model-row">
                <div class="setting-item setting-item-full">
                  <label>模型</label>
                  <a-select
                    v-model:value="selectedModel"
                    :bordered="false"
                    class="flat-select"
                    popup-class-name="generate-dropdown"
                  >
                    <a-select-option v-for="model in generationModels" :key="model.model_key" :value="model.model_key">
                      <div class="model-option">
                        <div class="model-option-label">{{ model.model_label }}</div>
                        <div v-if="model.model_description" class="model-option-desc">{{ model.model_description }}</div>
                      </div>
                    </a-select-option>
                  </a-select>
                </div>
              </div>

              <div class="field-block ref-upload-block">
                <div class="panel-head">
                  <h3>参考图</h3>
                  <span class="panel-hint">(可选，最多 {{ MAX_REFS }} 张)</span>
                </div>

                <input
                  ref="fileInput"
                  type="file"
                  accept="image/*"
                  hidden
                  @change="handleFileChange"
                />

                <div class="upload-grid">
                  <div v-for="(item, idx) in referenceItems" :key="item.id" class="upload-thumb">
                    <img :src="getReferencePreviewUrl(item)" alt="参考图" />
                    <div v-if="item.status !== 'success'" class="upload-thumb-mask" :class="{ error: item.status === 'failed' }">
                      <a-spin
                        v-if="item.status === 'uploading'"
                        :indicator="h(LoadingOutlined, { style: { fontSize: '18px', color: '#ff9f1a' } })"
                      />
                      <span v-else>上传失败</span>
                    </div>
                    <a-button
                      type="text"
                      shape="circle"
                      class="icon-chip danger thumb-remove"
                      @click="removeReference(idx)"
                    >
                      <template #icon><DeleteOutlined /></template>
                    </a-button>
                  </div>

                  <div
                    v-if="referenceItems.length < MAX_REFS"
                    class="upload-add"
                    @click="triggerUpload"
                  >
                    <a-spin
                      v-if="uploading"
                      :indicator="h(LoadingOutlined, { style: { fontSize: '20px', color: '#ff9f1a' } })"
                    />
                    <template v-else>
                      <CloudUploadOutlined style="font-size: 22px; color: #f0a62a" />
                      <span>Import</span>
                    </template>
                  </div>
                </div>
              </div>

              <div class="prompt-block">
                <div class="prompt-label-row">
                  <label>提示词</label>
                  <a-button type="text" class="history-btn" @click="openHistory">
                    <template #icon><ClockCircleOutlined /></template>
                  </a-button>
                </div>
                <a-textarea
                  v-model:value="prompt"
                  :rows="5"
                  placeholder="描述您想要生成的图片..."
                  class="prompt-input"
                  :maxlength="2000"
                  show-count
                />
              </div>

              <div class="settings-row settings-row-inline">
                <div class="setting-item setting-item-inline">
                  <label>宽高比</label>
                  <a-select
                    v-model:value="size"
                    :bordered="false"
                    class="flat-select"
                    popup-class-name="generate-dropdown"
                    :options="sizeOptions"
                  />
                </div>
                <div v-if="!hideResolution" class="setting-item setting-item-inline">
                  <label>分辨率</label>
                  <a-select
                    v-model:value="resolution"
                    :bordered="false"
                    class="flat-select"
                    popup-class-name="generate-dropdown"
                    :options="resolutionOptions"
                  />
                </div>
              </div>

              <div class="generate-actions-block">
                <div class="field-block">
                  <label>图片数量：{{ numImages }}</label>
                  <a-slider
                    v-model:value="numImages"
                    :min="1"
                    :max="4"
                    :marks="{ 1: '1', 2: '2', 3: '3', 4: '4' }"
                    class="num-slider"
                  />
                </div>

                <a-button
                  type="primary"
                  block
                  size="large"
                  :loading="loading"
                  :disabled="!activePrompt.trim() || hasBlockedUploads"
                  class="generate-btn"
                  @click="handleGenerate"
                >
                  <template #icon><ThunderboltOutlined /></template>
                  {{ generateButtonText }}
                </a-button>
              </div>
            </section>
          </a-tab-pane>

          <a-tab-pane key="promptReverse" tab="提示词反推">
            <section class="work-panel settings-panel prompt-reverse-panel">
              <div class="field-block">
                <div class="panel-head">
                  <h3>上传图片</h3>
                  <span class="panel-hint">(每次反推消耗 1 积分)</span>
                </div>

                <input
                  ref="reverseInput"
                  type="file"
                  accept="image/*"
                  hidden
                  @change="handleReverseFileChange"
                />

                <div
                  v-if="!reverseImageUrl"
                  class="source-upload-empty"
                  @click="triggerReverseUpload"
                >
                  <a-spin
                    v-if="reverseUploading"
                    :indicator="h(LoadingOutlined, { style: { fontSize: '20px', color: '#ff9f1a' } })"
                  />
                  <template v-else>
                    <CloudUploadOutlined class="source-upload-icon" />
                    <div class="source-upload-title">点击上传图片</div>
                    <div class="source-upload-desc">系统将自动分析图片内容并反推出专业中文提示词</div>
                  </template>
                </div>

                <div v-else class="reverse-preview-shell">
                  <button type="button" class="canvas-remove-btn" @click="removeReverseImage">
                    <CloseOutlined />
                  </button>
                  <img :src="reverseImageUrl" alt="提示词反推图片" class="reverse-preview-image" />
                </div>
              </div>

              <a-button
                type="primary"
                block
                size="large"
                :loading="reverseLoading || reverseUploading"
                class="generate-btn"
                @click="handlePromptReverse"
              >
                <template #icon><ThunderboltOutlined /></template>
                {{ promptReverseButtonText }}
              </a-button>

              <div v-if="reversePromptResult" class="reverse-result-card">
                <div class="panel-head">
                  <h3>反推结果</h3>
                </div>
                <a-textarea
                  :value="reversePromptResult"
                  :rows="8"
                  readonly
                  class="prompt-input reverse-result-input"
                />
                <div class="reverse-actions">
                  <a-button @click="copyReversePrompt">
                    <template #icon><CopyOutlined /></template>
                    复制提示词
                  </a-button>
                  <a-button type="primary" @click="applyReversePrompt">
                    带入文生图/图编辑
                  </a-button>
                </div>
              </div>

              <div v-else class="reverse-result-placeholder">
                上传图片后，点击「开始反推」即可获得适合 AI 绘画的中文提示词。
              </div>
            </section>
          </a-tab-pane>

          <a-tab-pane key="inpaint" tab="局部重绘">
            <section class="work-panel settings-panel inpaint-panel">
              <div class="field-block">
                <div class="panel-head">
                  <h3>绘制区域</h3>
                  <span class="panel-hint">(必传，涂抹后仅重绘选区)</span>
                </div>

                <input
                  ref="sourceInput"
                  type="file"
                  accept="image/*"
                  hidden
                  @change="handleSourceFileChange"
                />

                <div
                  v-if="!sourceDisplayUrl"
                  class="source-upload-empty"
                  @click="triggerSourceUpload"
                >
                  <a-spin
                    v-if="sourceUploading"
                    :indicator="h(LoadingOutlined, { style: { fontSize: '20px', color: '#ff9f1a' } })"
                  />
                  <template v-else>
                    <CloudUploadOutlined class="source-upload-icon" />
                    <div class="source-upload-title">点击上传原图</div>
                    <div class="source-upload-desc">上传后可直接在图片上涂抹需要重绘的区域</div>
                  </template>
                </div>

                <template v-else>
                  <div class="repaint-status-card" :class="{ ready: hasRepaintMask }">
                    <div class="repaint-status-title">
                      {{ hasRepaintMask ? "已选择重绘区域" : "请在图片上涂抹需要重绘的区域" }}
                    </div>
                    <div class="repaint-status-desc">
                      {{ hasRepaintMask ? "提交后只会修改已涂抹部分，未涂抹区域保持不变。" : "先上传原图，再直接在图片上绘制需要重绘的局部范围。" }}
                    </div>
                    <div v-if="sourceUploading || (!sourceImageUrl && sourcePreviewUrl)" class="repaint-status-uploading">
                      {{ sourceUploading ? "原图上传中，完成后可提交任务" : "原图上传未完成，请重新上传后再试" }}
                    </div>
                  </div>

                  <div class="repaint-canvas-shell">
                    <button type="button" class="canvas-remove-btn" @click="removeSourceImage">
                      <CloseOutlined />
                    </button>
                    <RepaintCanvas
                      ref="repaintCanvasRef"
                      :image-url="sourceDisplayUrl"
                      :brush-size="brushSize"
                      :tool="repaintTool"
                      @mask-change="handleMaskChange"
                    />
                  </div>

                  <div class="repaint-toolbar">
                    <button
                      type="button"
                      class="tool-btn"
                      :class="{ active: repaintTool === 'paint' }"
                      @click="repaintTool = 'paint'"
                    >
                      <EditOutlined />
                    </button>
                    <button
                      type="button"
                      class="tool-btn"
                      :class="{ active: repaintTool === 'erase' }"
                      @click="repaintTool = 'erase'"
                    >
                      <ClearOutlined />
                    </button>
                    <div class="toolbar-divider" />
                    <div class="toolbar-slider">
                      <a-slider v-model:value="brushSize" :min="12" :max="60" class="brush-slider" />
                    </div>
                    <div class="brush-preview" :style="{ width: `${Math.max(10, Math.min(brushSize, 34))}px`, height: `${Math.max(10, Math.min(brushSize, 34))}px` }" />
                    <div class="toolbar-divider" />
                    <button
                      type="button"
                      class="tool-btn"
                      @click="clearRepaintMask"
                    >
                      <ReloadOutlined />
                    </button>
                    <button
                      type="button"
                      class="tool-btn"
                      :disabled="!canUndoMask"
                      @click="undoRepaintMask"
                    >
                      <UndoOutlined />
                    </button>
                    <button
                      type="button"
                      class="tool-btn"
                      :disabled="!canRedoMask"
                      @click="redoRepaintMask"
                    >
                      <RedoOutlined />
                    </button>
                  </div>

                  <div class="mask-tip">
                    请直接在图片上涂抹需要重绘的区域，当前蒙层为 50% 透明度，提交时仅对白色蒙版区域进行重绘。
                  </div>
                </template>
              </div>

              <div class="prompt-block inpaint-prompt-block">
                <div class="prompt-label-row">
                  <label>提示词</label>
                </div>
                <a-textarea
                  v-model:value="repaintPrompt"
                  :rows="5"
                  placeholder="描述需要局部重绘后的效果..."
                  class="prompt-input"
                  :maxlength="2000"
                  show-count
                />
              </div>

              <a-button
                type="primary"
                block
                size="large"
                :loading="loading || sourceUploading"
                :disabled="!activePrompt.trim() || hasBlockedUploads"
                class="generate-btn"
                @click="handleGenerate"
              >
                <template #icon><ThunderboltOutlined /></template>
                {{ generateButtonText }}
              </a-button>
            </section>
          </a-tab-pane>
        </a-tabs>
      </div>

      <section class="work-panel result-panel">
        <div class="panel-head">
          <h3>生成结果</h3>
        </div>

        <div class="result-tips">
          <div class="result-tip-line">
            生图任务结果可在
            <router-link to="/history" class="result-tip-link">历史记录</router-link>
            中查看；
          </div>
          <div class="result-tip-line">服务器只保留原图15天，请尽快下载原图；</div>
        </div>

        <div v-if="images.length" class="result-list" :class="resultLayoutClass">
          <div
            v-for="(img, index) in images"
            :key="img.id"
            class="result-card"
            :class="{ 'result-card-single': images.length === 1 }"
          >
            <div class="result-card-head">
              <span>第 {{ index + 1 }} 张</span>
              <a-tag :color="img.status === 'success' ? 'blue' : img.status === 'failed' ? 'red' : 'gold'">
                {{
                  img.status === "success"
                    ? "已完成"
                    : img.status === "failed"
                      ? "生成失败"
                      : "生成中"
                }}
              </a-tag>
            </div>

            <div
              class="result-frame"
              :class="{
                single: images.length === 1,
                pending: img.status === 'pending',
                failed: img.status === 'failed',
                clickable: !!getResultDisplayUrl(img),
              }"
              @click="getResultDisplayUrl(img) && handlePreview(getResultDisplayUrl(img))"
            >
              <template v-if="img.status === 'success' && getResultDisplayUrl(img)">
                <img :src="getResultDisplayUrl(img)" alt="生成结果" />
                <div class="result-actions">
                  <a-button shape="circle" class="icon-chip" @click.stop="handlePreview(getResultDisplayUrl(img))">
                    <template #icon><EyeOutlined /></template>
                  </a-button>
                  <a-button shape="circle" class="icon-chip" @click.stop="handleDownload(img.id, img.image_url, img.preview_url)">
                    <template #icon><DownloadOutlined /></template>
                  </a-button>
                </div>
              </template>

              <template v-else-if="img.status === 'failed'">
                <img src="/failed-result.svg" alt="生成失败" class="failed-image" />
                <div class="frame-state error">
                  <span>生成失败，请重试</span>
                </div>
              </template>

              <template v-else>
                <div class="frame-state">
                  <a-spin
                    :indicator="h(LoadingOutlined, { style: { fontSize: '24px', color: '#7c8db5' } })"
                  />
                  <span>正在生成图片...</span>
                </div>
              </template>
            </div>

            <a-button
              block
              class="flat-action-btn"
              :disabled="img.status === 'pending'"
              @click="handleRegenerate(img.id)"
            >
              <template #icon><ReloadOutlined /></template>
              重新生成
            </a-button>
          </div>
        </div>

        <div v-else-if="!loading && pendingCount === 0" class="result-empty">
          <PictureOutlined class="empty-icon" />
          <div class="empty-title">{{ resultEmptyTitle }}</div>
          <div class="empty-desc">{{ resultEmptyDesc }}</div>
        </div>
      </section>
    </div>

    <!-- Prompt history dialog -->
    <a-modal
      v-model:open="historyVisible"
      title="历史提示词"
      :footer="null"
      :width="560"
      centered
    >
      <a-spin :spinning="historyLoading">
        <div v-if="historyItems.length === 0 && !historyLoading" class="history-empty">
          暂无历史提示词
        </div>
        <div v-else class="history-list">
          <div
            v-for="item in historyItems"
            :key="item.id"
            class="history-item"
            @click="useHistoryPrompt(item.prompt)"
          >
            <div class="history-text">{{ item.prompt }}</div>
            <a-button
              type="text"
              shape="circle"
              size="small"
              class="history-del"
              @click.stop="removeHistoryItem(item.id)"
            >
              <template #icon><DeleteOutlined /></template>
            </a-button>
          </div>
        </div>
      </a-spin>
    </a-modal>

    <div v-if="previewVisible" style="display: none">
      <a-image
        :src="previewCurrent"
        :preview="{
          visible: previewVisible,
          onVisibleChange: (v: boolean) => (previewVisible = v),
        }"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.generate-page {
  min-height: calc(100vh - 112px);
  --config-title-size: 14px;
  --config-title-gap: 10px;
  --config-title-color: #5e4524;
}

.generate-workbench {
  display: grid;
  grid-template-columns: 382fr 618fr;
  gap: 24px;
  align-items: start;
}

.left-col {
  display: flex;
  flex-direction: column;
}

.generate-tabs {
  :deep(.ant-tabs-nav) {
    margin-bottom: 18px;
  }

  :deep(.ant-tabs-tab) {
    padding: 10px 0 14px;
    font-size: 15px;
    font-weight: 700;
    color: #8f7558;
  }

  :deep(.ant-tabs-tab-active .ant-tabs-tab-btn) {
    color: #c98511 !important;
  }

  :deep(.ant-tabs-ink-bar) {
    height: 3px;
    border-radius: 99px;
    background: linear-gradient(90deg, #ffc45b, #ffab25);
  }

  :deep(.ant-tabs-content-holder) {
    overflow: visible;
  }

  :deep(.ant-tabs-tabpane) {
    display: flex;
    flex-direction: column;
    gap: 18px;
  }
}

/* --- Prompt (standalone) --- */
.prompt-block {
  display: flex;
  flex-direction: column;
}

.prompt-label-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--config-title-gap);

  label {
    color: var(--config-title-color);
    font-size: var(--config-title-size);
    font-weight: 700;
    line-height: 1.4;
  }
}

.history-btn {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  color: #a88962 !important;
  font-size: 17px;

  &:hover {
    color: #d38a12 !important;
    background: rgba(255, 214, 140, 0.28) !important;
  }
}

.prompt-input {
  border-radius: 14px !important;
  border-color: #efdcb9 !important;
  background: #fffdf8 !important;
  padding: 10px 14px;
  font-size: 14px;
  resize: none;

  &:focus,
  &:hover {
    border-color: #f0b85a !important;
    box-shadow: 0 0 0 3px rgba(255, 184, 90, 0.12);
  }
}

/* --- Settings row --- */
.settings-row {
  display: flex;
  gap: 16px;
}

.settings-row-inline {
  align-items: center;
}

.setting-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: var(--config-title-gap);

  label {
    color: var(--config-title-color);
    font-size: var(--config-title-size);
    font-weight: 700;
    line-height: 1.4;
  }
}

.setting-item-full {
  flex: 1 1 100%;
}

.setting-item-inline {
  flex-direction: row;
  align-items: center;
  gap: 10px;

  label {
    margin: 0;
    min-width: 56px;
    flex: 0 0 auto;
  }

  .flat-select {
    flex: 1;
  }
}

.generate-actions-block {
  display: flex;
  flex-direction: column;
}

/* --- Card panel --- */
.work-panel {
  background: linear-gradient(180deg, #fffaf0 0%, #fffefb 100%);
  border: 1px solid rgba(250, 186, 90, 0.24);
  border-radius: 24px;
  box-shadow: 0 18px 45px rgba(246, 178, 70, 0.12);
  padding: 20px;
}

.panel-head {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: var(--config-title-gap);

  h3 {
    font-size: var(--config-title-size);
    line-height: 1.4;
    color: var(--config-title-color);
    margin: 0;
    font-weight: 700;
  }
}

.panel-hint {
  font-size: 12px;
  color: #a88962;
  font-weight: 400;
}

/* --- Upload (compact) --- */
.upload-grid {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.upload-thumb {
  position: relative;
  width: 72px;
  height: 72px;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid #f0ddbb;
  flex-shrink: 0;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
}

.upload-thumb-mask {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px;
  background: rgba(255, 250, 240, 0.72);
  color: #8f7558;
  font-size: 12px;
  font-weight: 700;
  text-align: center;

  &.error {
    background: rgba(255, 245, 243, 0.84);
    color: #d6574b;
  }
}

.thumb-remove {
  position: absolute;
  top: 2px;
  right: 2px;
  width: 22px !important;
  height: 22px !important;
  font-size: 11px;
}

.upload-add {
  width: 72px;
  height: 72px;
  border-radius: 14px;
  border: 2px dashed #e8d7b7;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  cursor: pointer;
  color: #8f7558;
  font-size: 11px;
  background: linear-gradient(
    180deg,
    rgba(255, 255, 255, 0.9),
    rgba(255, 248, 232, 0.92)
  );
  transition: border-color 0.2s, transform 0.2s;
  flex-shrink: 0;

  &:hover {
    border-color: #f1bd57;
    transform: translateY(-1px);
  }
}

/* --- Fields --- */
.field-block + .field-block {
  margin-top: 16px;
}

.field-block label {
  display: block;
  margin-bottom: var(--config-title-gap);
  color: var(--config-title-color);
  font-size: var(--config-title-size);
  font-weight: 700;
  line-height: 1.4;
}

.flat-select {
  width: 100%;
  background: #fff;
  border-radius: 14px;
  border: 1px solid #f0ddbb;
  box-shadow: 0 8px 18px rgba(244, 182, 84, 0.08);

  :deep(.ant-select-selector) {
    height: 44px !important;
    padding: 0 14px !important;
    border: none !important;
    box-shadow: none !important;
    background: transparent !important;
    border-radius: 14px !important;
    font-weight: 600;
    color: #4b3318;
  }

  :deep(.ant-select-selection-item) {
    line-height: 44px !important;
  }
}

.model-option {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.model-option-label {
  font-weight: 700;
  color: #4b3318;
}

.model-option-desc {
  font-size: 12px;
  color: #8c7458;
}

/* --- Slider --- */
.num-slider {
  margin: 4px 6px 18px;

  :deep(.ant-slider-rail) {
    background: #f0ddbb;
    height: 6px;
    border-radius: 3px;
  }

  :deep(.ant-slider-track) {
    background: linear-gradient(90deg, #ffc45b, #ffab25);
    height: 6px;
    border-radius: 3px;
  }

  :deep(.ant-slider-handle) {
    width: 22px;
    height: 22px;
    margin-top: -8px;
    border: none;
    background: transparent;
    box-shadow: none;
    outline: none !important;

    &::after {
      width: 22px;
      height: 22px;
      inset-inline-start: 0;
      inset-block-start: 0;
      border-radius: 50%;
      border: 3px solid #ffab25;
      background: #fff;
      box-shadow: 0 4px 12px rgba(255, 171, 37, 0.3);
    }

    &:hover::after,
    &:focus::after {
      border-color: #ff9a16;
      box-shadow: 0 4px 16px rgba(255, 171, 37, 0.45);
    }
  }

  :deep(.ant-slider-dot) {
    width: 10px;
    height: 10px;
    border: 2px solid #e8d7b7;
    background: #fff;
    top: -2px;
  }

  :deep(.ant-slider-dot-active) {
    border-color: #ffab25;
  }

  :deep(.ant-slider-mark-text) {
    color: #a88962;
    font-size: 12px;
    font-weight: 600;
  }

  :deep(.ant-slider-mark-text-active) {
    color: #6f583a;
  }
}

.generate-btn {
  margin-top: 12px;
  height: 50px;
  border-radius: 16px;
  font-size: 15px;
  font-weight: 700;
  background: linear-gradient(180deg, #ffc45b, #ffab25) !important;
  border: none !important;
  box-shadow: 0 16px 28px rgba(255, 169, 37, 0.28) !important;
}

.source-upload-empty {
  min-height: 280px;
  padding: 26px 20px;
  border-radius: 20px;
  border: 2px dashed #e8d7b7;
  background: linear-gradient(180deg, #fffdf9, #fff7eb);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  cursor: pointer;
  transition: border-color 0.2s, transform 0.2s;

  &:hover {
    border-color: #f1bd57;
    transform: translateY(-1px);
  }
}

.source-upload-icon {
  font-size: 30px;
  color: #f0a62a;
}

.source-upload-title {
  margin-top: 12px;
  font-size: 16px;
  font-weight: 700;
  color: #5d4322;
}

.source-upload-desc {
  margin-top: 6px;
  color: #9b8160;
  font-size: 13px;
  line-height: 1.7;
}

.reverse-preview-shell {
  position: relative;
  border-radius: 20px;
  overflow: hidden;
  border: 1px solid #f0ddbb;
  background: #fff8ec;
}

.reverse-preview-image {
  width: 100%;
  display: block;
  max-height: 420px;
  object-fit: contain;
}

.reverse-result-card {
  margin-top: 2px;
  padding: 16px;
  border-radius: 20px;
  border: 1px solid #f0ddbb;
  background: #fffdf8;
}

.reverse-result-input {
  :deep(textarea) {
    min-height: 180px;
    font-family: "SF Mono", "Consolas", "Monaco", monospace;
    line-height: 1.7;
  }
}

.reverse-actions {
  display: flex;
  gap: 10px;
  margin-top: 12px;
  flex-wrap: wrap;
}

.reverse-result-placeholder {
  padding: 22px 18px;
  border-radius: 18px;
  border: 1px dashed #ead9b9;
  background: rgba(255, 248, 232, 0.38);
  color: #8f7558;
  font-size: 13px;
  line-height: 1.8;
}

.repaint-status-card {
  margin-bottom: 14px;
  padding: 14px 16px;
  border-radius: 16px;
  background: linear-gradient(180deg, #fff9ef, #fffdf8);
  border: 1px solid #f1dfbe;

  &.ready {
    background: linear-gradient(180deg, #fff5df, #fffaf0);
    border-color: #f0c36a;
  }
}

.repaint-status-title {
  color: #5d4322;
  font-size: 14px;
  font-weight: 700;
}

.repaint-status-desc {
  margin-top: 6px;
  color: #907659;
  font-size: 12px;
  line-height: 1.7;
}

.repaint-status-uploading {
  margin-top: 8px;
  color: #c98511;
  font-size: 12px;
  font-weight: 700;
}

.repaint-canvas-shell {
  position: relative;
  border-radius: 18px;
}

.canvas-remove-btn {
  position: absolute;
  top: 12px;
  right: 12px;
  z-index: 2;
  width: 40px;
  height: 40px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 14px;
  background: rgba(38, 38, 42, 0.84);
  color: rgba(255, 255, 255, 0.92);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  cursor: pointer;
  box-shadow: 0 8px 18px rgba(0, 0, 0, 0.18);
  backdrop-filter: blur(8px);
  transition: background 0.2s, transform 0.2s, border-color 0.2s;

  &:hover {
    background: rgba(48, 48, 54, 0.94);
    border-color: rgba(255, 255, 255, 0.24);
    transform: scale(1.03);
  }
}

.repaint-toolbar {
  margin-top: 14px;
  padding: 10px 14px;
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: linear-gradient(180deg, rgba(46, 46, 52, 0.96), rgba(34, 34, 38, 0.96));
  display: flex;
  align-items: center;
  gap: 10px;
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.18);
}

.tool-btn {
  width: 42px;
  height: 42px;
  border: 1px solid transparent;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.06);
  color: rgba(255, 255, 255, 0.9);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  cursor: pointer;
  transition: background 0.2s, color 0.2s, opacity 0.2s, border-color 0.2s, transform 0.2s;

  &:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.12);
    border-color: rgba(255, 255, 255, 0.12);
    transform: translateY(-1px);
  }

  &.active {
    background: linear-gradient(180deg, rgba(116, 107, 255, 0.9), rgba(95, 91, 240, 0.9));
    color: #fff;
    border-color: rgba(170, 167, 255, 0.38);
    box-shadow: 0 10px 18px rgba(90, 87, 230, 0.24);
  }

  &:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }
}

.toolbar-divider {
  width: 1px;
  height: 30px;
  background: rgba(255, 255, 255, 0.12);
}

.toolbar-slider {
  flex: 1;
  min-width: 120px;
  max-width: 180px;
}

.brush-preview {
  flex: 0 0 auto;
  min-width: 10px;
  min-height: 10px;
  max-width: 34px;
  max-height: 34px;
  border-radius: 50%;
  background: rgba(255, 171, 37, 0.5);
  border: 1px solid rgba(255, 255, 255, 0.56);
  box-shadow:
    0 0 0 6px rgba(255, 255, 255, 0.06),
    0 4px 10px rgba(0, 0, 0, 0.16);
}

.brush-slider {
  margin: 0 4px;

  :deep(.ant-slider-rail) {
    height: 8px;
    background: rgba(255, 255, 255, 0.2);
    border-radius: 999px;
  }

  :deep(.ant-slider-track) {
    height: 8px;
    background: #6d6cff;
    border-radius: 999px;
  }

  :deep(.ant-slider-handle) {
    width: 24px;
    height: 24px;
    margin-top: -8px;
    border: none;
    background: transparent;
    box-shadow: none;

    &::after {
      width: 24px;
      height: 24px;
      border-color: #6d6cff;
      background: #fff;
      box-shadow: 0 4px 12px rgba(57, 56, 138, 0.32);
    }
  }
}

.mask-tip {
  margin-top: 12px;
  color: #8f7558;
  font-size: 13px;
  line-height: 1.7;
}

.inpaint-prompt-block {
  margin-top: 6px;
}

/* --- Results --- */
.result-panel {
  min-height: calc(100vh - 156px);
  display: flex;
  flex-direction: column;
}

.result-tips {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-bottom: 4px;
}

.result-tip-line {
  color: #8f7558;
  font-size: 13px;
  line-height: 1.7;
}

.result-tip-link {
  color: #d38a12;
  font-weight: 700;
  text-decoration: none;

  &:hover {
    color: #b87408;
    text-decoration: underline;
  }
}

.result-list {
  display: grid;
  gap: 16px;
  margin-top: 16px;
  grid-template-columns: 1fr;
}

.result-list-double {
  grid-template-columns: repeat(2, 1fr);
}

.result-card {
  padding: 14px;
  border-radius: 20px;
  border: 1px solid #f1dfbe;
  background: rgba(255, 255, 255, 0.78);
}

.result-card-single {
  padding: 16px;
}

.result-card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 10px;
  color: #594223;
  font-size: 13px;
  font-weight: 700;
}

.result-frame {
  position: relative;
  min-height: 180px;
  border-radius: 18px;
  overflow: hidden;
  border: 1px dashed #ead9b9;
  background: #fffaf0;

  &.single {
    min-height: 520px;
  }

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  &.clickable {
    cursor: pointer;
  }

  &.pending {
    background: linear-gradient(180deg, #fffaf0, #fffdf9);
  }

  &.failed {
    background: #fff7f5;
  }
}

.failed-image {
  object-fit: contain !important;
  padding: 28px;
  background: #fffdfb;
  opacity: 0.96;
}

.result-actions {
  position: absolute;
  inset: auto 12px 12px auto;
  display: flex;
  gap: 8px;
}

.frame-state {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: #8d7758;
  font-size: 14px;
  background: rgba(255, 250, 240, 0.74);

  &.error {
    background: linear-gradient(
      180deg,
      rgba(255, 247, 245, 0.4),
      rgba(255, 247, 245, 0.86)
    );
    color: #d45b4d;
  }
}

.flat-action-btn {
  margin-top: 10px;
  height: 40px;
  border-radius: 12px;
  border: 1px solid #f0ddbb;
  background: #fff !important;
  color: #6f583a !important;
  font-weight: 700;

  &:hover,
  &:focus {
    border-color: #f5b64c !important;
    color: #d38a12 !important;
  }
}

.icon-chip {
  width: 36px;
  height: 36px;
  border: none !important;
  background: rgba(255, 255, 255, 0.92) !important;
  color: #684825 !important;
  box-shadow: 0 10px 16px rgba(0, 0, 0, 0.1);

  &.danger {
    color: #d6574b !important;
  }
}

/* --- Empty state --- */
.result-empty {
  flex: 1;
  min-height: 320px;
  border-radius: 20px;
  border: 1px dashed #ead9b9;
  background: linear-gradient(
    180deg,
    rgba(255, 248, 232, 0.38),
    rgba(255, 253, 248, 0.82)
  );
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

.empty-icon {
  font-size: 48px;
  color: #e8d7b7;
}

.empty-title {
  font-size: 17px;
  font-weight: 700;
  color: #8f7558;
}

.empty-desc {
  font-size: 13px;
  color: #b8a080;
}

/* --- History dialog --- */
.history-empty {
  text-align: center;
  padding: 32px 0;
  color: #a88962;
  font-size: 14px;
}

.history-list {
  max-height: 420px;
  overflow-y: auto;
}

.history-item {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 12px;
  cursor: pointer;
  transition: background 0.15s;

  &:hover {
    background: #fff8ec;
  }

  & + & {
    border-top: 1px solid #f5ead5;
  }
}

.history-text {
  flex: 1;
  font-size: 13px;
  color: #4c341a;
  line-height: 1.6;
  word-break: break-all;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.history-del {
  flex-shrink: 0;
  color: #c0a578 !important;
  margin-top: 2px;

  &:hover {
    color: #d6574b !important;
  }
}

:deep(.generate-dropdown.ant-select-dropdown) {
  border-radius: 14px;
  padding: 6px;
  background: #fffefb;
  border: 1px solid #f0ddbb;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

@media (max-width: 960px) {
  .generate-workbench {
    grid-template-columns: 1fr;
  }

  .result-panel {
    min-height: auto;
  }

  .result-list-double {
    grid-template-columns: repeat(2, 1fr);
  }

  .result-list-single {
    grid-template-columns: 1fr;
  }

  .result-frame.single {
    min-height: 420px;
  }
}

@media (max-width: 640px) {
  .work-panel {
    padding: 16px;
    border-radius: 20px;
  }

  .settings-row {
    flex-direction: column;
  }

  .upload-thumb,
  .upload-add {
    width: 60px;
    height: 60px;
  }

  .result-list {
    grid-template-columns: 1fr;
  }

  .result-frame.single {
    min-height: 320px;
  }
}
</style>
