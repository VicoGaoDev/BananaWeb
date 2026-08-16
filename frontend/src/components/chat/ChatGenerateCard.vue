<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { message } from "ant-design-vue";
import { getPreviewImageSrc, resolveImageUrl } from "@/api/images";
import { getAdminTasks } from "@/api/admin";
import { confirmChatMessageGenerate } from "@/api/chat";
import { getTaskScenes } from "@/api/config";
import { getTasks } from "@/api/tasks";
import AspectRatioPicker from "@/components/generate/AspectRatioPicker.vue";
import OptionGridPicker from "@/components/generate/OptionGridPicker.vue";
import type { ChatGenerateInfo, ChatMessage, SceneOptionItem, TaskResult, TaskSceneConfig } from "@/types";

const IMAGE_COUNT_OPTIONS: SceneOptionItem[] = Array.from({ length: 8 }, (_, index) => {
  const value = String(index + 1);
  return { label: value, value };
});

const props = defineProps<{
  sessionId: string;
  messageId: number;
  generate: ChatGenerateInfo;
  readonly?: boolean;
  adminViewer?: boolean;
}>();

const emit = defineEmits<{
  updated: [value: ChatMessage];
  preview: [url: string];
}>();

const scenes = ref<TaskSceneConfig[]>([]);
const submitting = ref(false);
const confirming = ref(false);
const promptExpanded = ref(false);
const selectedModel = ref("");
const numImages = ref(1);
const size = ref("");
const resolution = ref("");
const customSize = ref("");
const tasks = ref<TaskResult[]>([]);
let pollTimer: number | null = null;

const generateInfo = computed(() => props.generate);
const isPending = computed(() => generateInfo.value.status === "pending_confirm");
const canEdit = computed(() => isPending.value && !props.readonly);
const modeHint = computed(() => (
  generateInfo.value.reference_images?.length ? "image_edit" : (generateInfo.value.mode_hint || "generate")
));
const modeLabel = computed(() => (modeHint.value === "image_edit" ? "图编辑" : "文生图"));
const modelOptions = computed(() => (
  scenes.value.filter((item) => item.scene_type === modeHint.value)
));
const modelPickerOptions = computed<SceneOptionItem[]>(() => (
  modelOptions.value.map((item) => ({
    label: item.scene_label || item.display_name || item.scene_key,
    value: item.scene_key,
  }))
));
const selectedScene = computed(() => (
  modelOptions.value.find((item) => item.scene_key === selectedModel.value) || null
));
const sizeOptions = computed(() => selectedScene.value?.aspect_ratio_options || []);
const resolutionOptions = computed(() => selectedScene.value?.image_size_options || []);
const customSizeOptions = computed(() => selectedScene.value?.custom_size_options || []);
const showSize = computed(() => canEdit.value && !!selectedScene.value && !selectedScene.value.hide_aspect_ratio && sizeOptions.value.length > 0);
const showResolution = computed(() => canEdit.value && !!selectedScene.value && !selectedScene.value.hide_resolution && resolutionOptions.value.length > 0);
const showCustomSize = computed(() => canEdit.value && !!selectedScene.value && !selectedScene.value.hide_custom_size && customSizeOptions.value.length > 0);
const selectedNumImages = computed({
  get: () => String(numImages.value),
  set: (value: string) => {
    numImages.value = Math.min(8, Math.max(1, Number(value) || 1));
  },
});
const promptText = computed(() => (generateInfo.value.prompt || "").trim());
const promptPreview = computed(() => {
  if (promptExpanded.value || promptText.value.length <= 90) return promptText.value;
  return `${promptText.value.slice(0, 90)}…`;
});
const estimatedCost = computed(() => {
  const scene = selectedScene.value;
  if (!scene) return 0;
  const resolutionKey = (resolution.value || "").trim();
  const resolutionCosts = scene.resolution_credit_costs || {};
  const unit = resolutionKey && Object.prototype.hasOwnProperty.call(resolutionCosts, resolutionKey)
    ? Number(resolutionCosts[resolutionKey] || 0)
    : Number(scene.credit_cost || 0);
  return unit * Math.max(1, Number(numImages.value || 1));
});
const resultImages = computed(() => (
  tasks.value.flatMap((task) => (task.images || []).filter((item) => item.image_url && item.status !== "failed"))
));
const tasksSettled = computed(() => (
  tasks.value.length > 0
  && tasks.value.every((item) => item.status === "success" || item.status === "failed")
));
const isGenerating = computed(() => {
  if (tasksSettled.value) return false;
  if (confirming.value) return true;
  if (generateInfo.value.status === "running") return true;
  return tasks.value.some((item) => item.status === "processing" || item.status === "queued" || item.status === "pending");
});
const resultSlots = computed(() => {
  if (generateInfo.value.status === "cancelled" && !tasks.value.length) return [];
  if (isPending.value && !confirming.value) return [];
  const count = Math.max(
    Number(generateInfo.value.num_images || numImages.value || 1),
    generateInfo.value.task_ids?.length || 0,
    tasks.value.length,
    resultImages.value.length,
  );
  if (!count || (!isGenerating.value && !tasks.value.length && generateInfo.value.status !== "success" && generateInfo.value.status !== "failed")) {
    return [];
  }
  return Array.from({ length: count }, (_, index) => {
    const task = tasks.value[index];
    const image = (task?.images || []).find((item) => item.image_url && item.status === "success")
      || (task?.images || []).find((item) => item.image_url)
      || resultImages.value[index];
    const displayUrl = (image?.thumb_url || image?.preview_url || image?.image_url || "").trim();
    const previewUrl = (image?.image_url || image?.preview_url || "").trim();
    if ((previewUrl || displayUrl) && image?.status !== "failed" && task?.status !== "failed") {
      return { key: `ok-${image?.id || index}`, status: "success" as const, url: displayUrl || previewUrl, previewUrl };
    }
    if (task?.status === "failed" || image?.status === "failed") {
      return { key: `fail-${task?.id || index}`, status: "failed" as const, url: "", previewUrl: "" };
    }
    if (!task && generateInfo.value.status === "failed") {
      return { key: `fail-${index}`, status: "failed" as const, url: "", previewUrl: "" };
    }
    return { key: `pending-${task?.id || index}`, status: "pending" as const, url: "", previewUrl: "" };
  });
});
const resultAspectRatio = computed(() => {
  const raw = (generateInfo.value.custom_size || generateInfo.value.size || "").trim();
  const ratioMatch = raw.match(/^(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)$/);
  if (ratioMatch) return `${ratioMatch[1]} / ${ratioMatch[2]}`;
  const sizeMatch = raw.match(/^(\d+(?:\.\d+)?)\s*[xX]\s*(\d+(?:\.\d+)?)$/);
  if (sizeMatch) return `${sizeMatch[1]} / ${sizeMatch[2]}`;
  return "1 / 1";
});
const failedMessage = computed(() => {
  if (generateInfo.value.error_message) return generateInfo.value.error_message;
  const failed = tasks.value.find((item) => item.status === "failed");
  return failed?.error_message || failed?.provider_error_message || "";
});
const statusLabel = computed(() => {
  if (generateInfo.value.status === "cancelled") return "已取消";
  if (generateInfo.value.status === "failed") return "生成失败";
  if (tasksSettled.value) {
    if (tasks.value.every((item) => item.status === "failed")) return "生成失败";
    if (tasks.value.some((item) => item.status === "success")) return "已生成";
  }
  if (isGenerating.value) return "正在生成…";
  if (generateInfo.value.status === "success" || resultSlots.value.some((slot) => slot.status === "success")) {
    return "已生成";
  }
  return modeLabel.value;
});

function firstOptionValue(items?: { value: string }[]) {
  return (items?.[0]?.value || "").trim();
}

function applySceneDefaults(scene: TaskSceneConfig | null) {
  if (!scene) return;
  const nextSizes = scene.aspect_ratio_options || [];
  const nextResolutions = scene.image_size_options || [];
  const nextCustoms = scene.custom_size_options || [];
  if (scene.hide_aspect_ratio) size.value = "";
  else if (!nextSizes.some((item) => item.value === size.value)) size.value = firstOptionValue(nextSizes);
  if (scene.hide_resolution) resolution.value = "";
  else if (!nextResolutions.some((item) => item.value === resolution.value)) {
    resolution.value = firstOptionValue(nextResolutions);
  }
  if (scene.hide_custom_size) customSize.value = "";
  else if (!nextCustoms.some((item) => item.value === customSize.value)) {
    customSize.value = firstOptionValue(nextCustoms);
  }
}

function imageSrc(url: string) {
  return resolveImageUrl((url || "").trim());
}

function referenceSrc(url: string) {
  return getPreviewImageSrc((url || "").trim());
}

function handlePreviewSlot(slot: { status: string; url: string; previewUrl: string }) {
  if (slot.status !== "success") return;
  const url = (slot.previewUrl || "").trim();
  if (url) emit("preview", url);
}

function replaceMessage(next: ChatMessage) {
  emit("updated", next);
}

async function loadScenes() {
  try {
    scenes.value = await getTaskScenes();
  } catch {
    scenes.value = [];
  }
  if (!selectedModel.value) {
    selectedModel.value = generateInfo.value.model || modelOptions.value[0]?.scene_key || "";
  }
  numImages.value = generateInfo.value.num_images || 1;
  size.value = generateInfo.value.size || "";
  resolution.value = generateInfo.value.resolution || "";
  customSize.value = generateInfo.value.custom_size || "";
  applySceneDefaults(selectedScene.value);
}

async function refreshTasks() {
  const ids = generateInfo.value.task_ids || [];
  if (!ids.length) return;
  try {
    tasks.value = props.adminViewer ? await getAdminTasks(ids) : await getTasks(ids);
  } catch {
    // keep last snapshot
  }
}

function stopPolling() {
  if (pollTimer != null) {
    window.clearInterval(pollTimer);
    pollTimer = null;
  }
}

function startPolling() {
  stopPolling();
  void refreshTasks();
  pollTimer = window.setInterval(() => {
    void refreshTasks();
  }, 5000);
}

watch(selectedModel, () => {
  if (!canEdit.value) return;
  applySceneDefaults(selectedScene.value);
});

watch(
  () => generateInfo.value.status,
  (status) => {
    if (status !== "pending_confirm") confirming.value = false;
    if (status === "running" || (generateInfo.value.task_ids || []).length) startPolling();
    else stopPolling();
  },
  { immediate: true },
);

watch(
  () => tasks.value.map((item) => item.status).join(","),
  () => {
    if (!tasks.value.length) return;
    if (tasks.value.every((item) => item.status === "success" || item.status === "failed")) {
      stopPolling();
    }
  },
);

async function handleConfirm() {
  if (!canEdit.value || submitting.value) return;
  if (!selectedModel.value) {
    message.warning("请选择生图模型");
    return;
  }
  confirming.value = true;
  submitting.value = true;
  try {
    const next = await confirmChatMessageGenerate(props.sessionId, props.messageId, {
      action: "confirm",
      model: selectedModel.value,
      num_images: numImages.value,
      size: showSize.value ? size.value : "",
      resolution: showResolution.value ? resolution.value : "",
      custom_size: showCustomSize.value ? customSize.value : "",
    });
    replaceMessage(next);
  } catch (err: any) {
    confirming.value = false;
    message.error(err?.response?.data?.detail || err?.message || "创建生图任务失败");
  } finally {
    submitting.value = false;
  }
}

async function handleCancel() {
  if (!canEdit.value || submitting.value) return;
  submitting.value = true;
  try {
    const next = await confirmChatMessageGenerate(props.sessionId, props.messageId, {
      action: "cancel",
    });
    replaceMessage(next);
  } catch (err: any) {
    message.error(err?.response?.data?.detail || err?.message || "取消失败");
  } finally {
    submitting.value = false;
  }
}

onMounted(() => {
  void loadScenes();
});

onBeforeUnmount(() => {
  stopPolling();
});
</script>

<template>
  <div class="chat-generate-card" :class="`is-${generateInfo.status}`">
    <div class="chat-generate-head">
      <strong>生图确认</strong>
      <span>{{ statusLabel }}</span>
    </div>
    <p v-if="promptText" class="chat-generate-prompt">
      {{ promptPreview }}
      <button
        v-if="promptText.length > 90"
        type="button"
        class="chat-generate-link"
        @click="promptExpanded = !promptExpanded"
      >
        {{ promptExpanded ? "收起" : "展开" }}
      </button>
    </p>
    <div v-if="generateInfo.reference_images?.length" class="chat-generate-refs">
      <button
        v-for="url in generateInfo.reference_images"
        :key="url"
        type="button"
        class="chat-generate-ref"
        @click="emit('preview', url)"
      >
        <img :src="referenceSrc(url)" alt="" />
      </button>
    </div>
    <div v-if="canEdit" class="chat-generate-fields">
      <label>
        <span>模型</span>
        <OptionGridPicker
          v-model="selectedModel"
          :options="modelPickerOptions"
          panel-title="选择模型"
          placeholder="选择模型"
          :columns="1"
        />
      </label>
      <label>
        <span>张数</span>
        <OptionGridPicker
          v-model="selectedNumImages"
          :options="IMAGE_COUNT_OPTIONS"
          panel-title="选择图片数量"
          placeholder="选择图片数量"
        />
      </label>
      <label v-if="showSize">
        <span>比例</span>
        <AspectRatioPicker v-model="size" :options="sizeOptions" />
      </label>
      <label v-if="showResolution">
        <span>分辨率</span>
        <OptionGridPicker
          v-model="resolution"
          :options="resolutionOptions"
          panel-title="选择分辨率"
          placeholder="选择分辨率"
        />
      </label>
      <label v-if="showCustomSize">
        <span>尺寸</span>
        <OptionGridPicker
          v-model="customSize"
          :options="customSizeOptions"
          panel-title="选择分辨率"
          placeholder="选择分辨率"
          show-preview
        />
      </label>
    </div>
    <div v-else-if="generateInfo.model" class="chat-generate-meta">
      {{ selectedScene?.scene_label || generateInfo.model }}
      · {{ generateInfo.num_images || 1 }} 张
      <template v-if="generateInfo.size"> · {{ generateInfo.size }}</template>
      <template v-if="generateInfo.resolution"> · {{ generateInfo.resolution }}</template>
    </div>
    <div v-if="resultSlots.length" class="chat-generate-results">
      <button
        v-for="slot in resultSlots"
        :key="slot.key"
        type="button"
        class="chat-generate-result"
        :class="`is-${slot.status}`"
        :style="{ aspectRatio: resultAspectRatio }"
        @click="handlePreviewSlot(slot)"
      >
        <img v-if="slot.status === 'success' && slot.url" :src="imageSrc(slot.url)" alt="" />
        <span v-else class="chat-generate-result-state">
          <span v-if="slot.status === 'pending'" class="chat-generate-result-spin" />
          {{ slot.status === "failed" ? "生成失败" : "生成中" }}
        </span>
      </button>
    </div>
    <p v-if="failedMessage" class="chat-generate-error">{{ failedMessage }}</p>
    <div v-if="canEdit" class="chat-generate-actions">
      <span class="chat-generate-cost">预计 {{ estimatedCost }} 积分</span>
      <button type="button" class="chat-generate-cancel" :disabled="submitting" @click="handleCancel">取消</button>
      <button type="button" class="chat-generate-confirm" :disabled="submitting" @click="handleConfirm">
        {{ submitting ? "提交中…" : "确认生图" }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.chat-generate-card {
  margin-top: 10px;
  padding: 12px;
  border-radius: 12px;
  border: 1px solid var(--theme-panel-border, rgba(0, 0, 0, 0.08));
  background: color-mix(in srgb, var(--theme-panel-bg, #fff9f0) 72%, #fff);
}

.chat-generate-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 8px;
  color: var(--theme-title, #3d2f22);
  font-size: 13px;
}

.chat-generate-head span {
  color: var(--theme-text-secondary, #8b7457);
  font-size: 12px;
}

.chat-generate-prompt {
  margin: 0 0 8px;
  color: var(--theme-title, #3d2f22);
  font-size: 13px;
  line-height: 1.55;
  white-space: pre-wrap;
  word-break: break-word;
}

.chat-generate-link,
.chat-generate-cancel,
.chat-generate-confirm {
  border: 0;
  background: transparent;
  cursor: pointer;
}

.chat-generate-link {
  margin-left: 6px;
  padding: 0;
  color: var(--theme-link, #d38a12);
  font-size: 12px;
}

.chat-generate-refs,
.chat-generate-results {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 8px;
}

.chat-generate-results {
  margin-top: 4px;
}

.chat-generate-ref,
.chat-generate-result {
  width: 56px;
  height: 56px;
  padding: 0;
  overflow: hidden;
  border: 0;
  border-radius: 8px;
  background: transparent;
  cursor: pointer;
}

.chat-generate-result {
  width: 112px;
  height: auto;
  min-height: 112px;
  border: 1px solid color-mix(in srgb, var(--theme-title, #3d2f22) 8%, transparent);
  background: color-mix(in srgb, var(--theme-title, #3d2f22) 4%, #fff);
}

.chat-generate-result.is-pending {
  cursor: default;
  background:
    linear-gradient(120deg, transparent 0%, color-mix(in srgb, var(--theme-accent, #f7a831) 16%, transparent) 46%, transparent 100%),
    color-mix(in srgb, var(--theme-title, #3d2f22) 5%, #fff);
  background-size: 180% 100%, 100% 100%;
  animation: chat-generate-shimmer 1.6s ease-in-out infinite;
}

.chat-generate-result.is-failed {
  cursor: default;
  border-color: color-mix(in srgb, #b42318 22%, transparent);
  background: color-mix(in srgb, #b42318 6%, #fff);
}

.chat-generate-result:disabled {
  cursor: default;
}

.chat-generate-ref img,
.chat-generate-result img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.chat-generate-result-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  height: 100%;
  min-height: 112px;
  color: var(--theme-text-secondary, #8b7457);
  font-size: 12px;
}

.chat-generate-result.is-failed .chat-generate-result-state {
  color: #b42318;
}

.chat-generate-result-spin {
  width: 18px;
  height: 18px;
  border: 2px solid color-mix(in srgb, var(--theme-accent, #f7a831) 28%, transparent);
  border-top-color: var(--theme-accent, #f7a831);
  border-radius: 50%;
  animation: chat-generate-spin 0.8s linear infinite;
}

@keyframes chat-generate-spin {
  to { transform: rotate(360deg); }
}

@keyframes chat-generate-shimmer {
  0% { background-position: 120% 0, 0 0; }
  100% { background-position: -80% 0, 0 0; }
}

.chat-generate-fields {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-bottom: 10px;
}

.chat-generate-fields label {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
  color: var(--theme-text-secondary, #8b7457);
  font-size: 12px;
}

.chat-generate-fields :deep(.option-grid-trigger) {
  width: 100%;
  min-width: 0;
  min-height: 34px;
  padding: 0 10px;
  border-radius: 12px;
  font-size: 13px;
}

.chat-generate-meta,
.chat-generate-cost {
  color: var(--theme-text-secondary, #8b7457);
  font-size: 12px;
}

.chat-generate-meta {
  margin: 2px 0 14px;
}

.chat-generate-error {
  margin: 0 0 8px;
  color: #b42318;
  font-size: 12px;
}

.chat-generate-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}

.chat-generate-cost {
  margin-right: auto;
}

.chat-generate-cancel,
.chat-generate-confirm {
  height: 30px;
  padding: 0 12px;
  border-radius: 8px;
  font-size: 13px;
}

.chat-generate-cancel {
  background: color-mix(in srgb, var(--theme-title, #3d2f22) 6%, transparent);
  color: var(--theme-title, #3d2f22);
}

.chat-generate-confirm {
  background: var(--theme-accent, #f7a831);
  color: var(--theme-accent-contrast, #3d2f22);
  font-weight: 700;
}

.chat-generate-cancel:disabled,
.chat-generate-confirm:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
