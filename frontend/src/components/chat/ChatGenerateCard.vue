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
import { notifyGeneratePageOfChatTasks } from "@/lib/chatGenerateDraft";
import { formatGenerationTaskFailureMessage, GENERATION_TASK_FAILURE_MESSAGE } from "@/lib/generationErrors";
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
const tasksFetched = ref(false);
const loadedImageKeys = ref<Set<string>>(new Set());
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
const tasksMissing = computed(() => (
  tasksFetched.value
  && (generateInfo.value.task_ids || []).length > 0
  && tasks.value.length === 0
));
const isGenerating = computed(() => {
  if (tasksSettled.value || tasksMissing.value) return false;
  if (confirming.value) return true;
  if (tasks.value.length) {
    return tasks.value.some((item) => item.status === "processing" || item.status === "queued" || item.status === "pending");
  }
  if (generateInfo.value.status === "success") return false;
  if (generateInfo.value.status === "running") return true;
  return false;
});
const hasKnownSuccess = computed(() => (
  generateInfo.value.status === "success"
  || resultImages.value.length > 0
  || tasks.value.some((item) => item.status === "success")
));
const allTasksFailed = computed(() => (
  tasksSettled.value && tasks.value.every((item) => item.status === "failed")
));
const canRetry = computed(() => (
  !props.readonly
  && !props.adminViewer
  && !isGenerating.value
  && (
    generateInfo.value.status === "failed"
    || tasksMissing.value
    || allTasksFailed.value
  )
));
const resultSlots = computed(() => {
  if (generateInfo.value.status === "cancelled" && !tasks.value.length) return [];
  if (isPending.value && !confirming.value) return [];
  const count = Math.max(
    Number(generateInfo.value.num_images || numImages.value || 1),
    generateInfo.value.task_ids?.length || 0,
    tasks.value.length,
    resultImages.value.length,
  );
  if (!count || (!isGenerating.value && !tasks.value.length && generateInfo.value.status !== "success" && generateInfo.value.status !== "failed" && !tasksMissing.value)) {
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
    if (!task && (generateInfo.value.status === "failed" || tasksMissing.value)) {
      return { key: `fail-${index}`, status: "failed" as const, url: "", previewUrl: "" };
    }
    if (hasKnownSuccess.value || task?.status === "success") {
      return { key: `load-${task?.id || index}`, status: "loading" as const, url: "", previewUrl: "" };
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
  if (generateInfo.value.status !== "failed" && !tasksMissing.value && !allTasksFailed.value) {
    return "";
  }
  const failed = tasks.value.find((item) => item.status === "failed");
  return formatGenerationTaskFailureMessage(
    generateInfo.value.error_message || failed?.error_message || failed?.provider_error_message || "",
    Boolean(failed?.credit_refunded),
  );
});
const isLoadingResults = computed(() => (
  resultSlots.value.some((slot) => (
    slot.status === "loading"
    || (slot.status === "success" && !!slot.url && !loadedImageKeys.value.has(slot.key))
  ))
));
const statusLabel = computed(() => {
  if (generateInfo.value.status === "cancelled") return "已取消";
  if (generateInfo.value.status === "failed" || tasksMissing.value) return "生成失败";
  if (tasksSettled.value && tasks.value.every((item) => item.status === "failed")) return "生成失败";
  if (isGenerating.value) return "正在生成…";
  if (isLoadingResults.value) return "加载中…";
  if (generateInfo.value.status === "success" || resultSlots.value.some((slot) => slot.status === "success")) {
    return "已生成";
  }
  return modeLabel.value;
});

function isImageReady(slot: { key: string; status: string; url: string }) {
  return slot.status === "success" && !!slot.url && loadedImageKeys.value.has(slot.key);
}

function markImageReady(key: string) {
  if (loadedImageKeys.value.has(key)) return;
  const next = new Set(loadedImageKeys.value);
  next.add(key);
  loadedImageKeys.value = next;
}

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

function notifyGeneratePage(next: ChatMessage) {
  if (props.adminViewer) return;
  const generate = next.generate;
  const taskIds = generate?.task_ids || [];
  if (!generate || !taskIds.length) return;
  notifyGeneratePageOfChatTasks({
    taskIds,
    prompt: generate.prompt,
    model: generate.model || selectedModel.value,
    numImages: generate.num_images || numImages.value,
    size: generate.size || size.value,
    resolution: generate.resolution || resolution.value,
    customSize: generate.custom_size || customSize.value,
    referenceImages: generate.reference_images || [],
    modeHint: generate.mode_hint,
  });
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
    tasksFetched.value = true;
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
  () => `${props.sessionId}:${props.messageId}`,
  () => {
    tasks.value = [];
    tasksFetched.value = false;
    loadedImageKeys.value = new Set();
  },
);

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
  () => [tasksMissing.value, tasks.value.map((item) => item.status).join(",")].join("|"),
  () => {
    if (tasksMissing.value) {
      stopPolling();
      return;
    }
    if (!tasks.value.length) return;
    if (tasks.value.every((item) => item.status === "success" || item.status === "failed")) {
      stopPolling();
    }
  },
);

watch(
  () => {
    if (tasksMissing.value) return "failed";
    if (!tasksSettled.value) return "";
    return tasks.value.every((item) => item.status === "failed") ? "failed" : "success";
  },
  (nextStatus) => {
    if (!nextStatus || generateInfo.value.status === nextStatus) return;
    emit("updated", {
      id: props.messageId,
      session_id: props.sessionId,
      generate: {
        ...generateInfo.value,
        status: nextStatus,
        error_message: nextStatus === "failed"
          ? (failedMessage.value || GENERATION_TASK_FAILURE_MESSAGE)
          : "",
      },
    } as ChatMessage);
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
    notifyGeneratePage(next);
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

async function handleRetry() {
  if (!canRetry.value || submitting.value) return;
  confirming.value = true;
  submitting.value = true;
  tasks.value = [];
  tasksFetched.value = false;
  try {
    const next = await confirmChatMessageGenerate(props.sessionId, props.messageId, {
      action: "retry",
      model: selectedModel.value || generateInfo.value.model || "",
      num_images: generateInfo.value.num_images || numImages.value,
      size: generateInfo.value.size || size.value,
      resolution: generateInfo.value.resolution || resolution.value,
      custom_size: generateInfo.value.custom_size || customSize.value,
    });
    tasks.value = [];
    tasksFetched.value = false;
    replaceMessage(next);
    notifyGeneratePage(next);
  } catch (err: any) {
    confirming.value = false;
    message.error(err?.response?.data?.detail || err?.message || "重试失败");
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
        :class="`is-${slot.status === 'success' && !isImageReady(slot) ? 'loading' : slot.status}`"
        :style="{ aspectRatio: resultAspectRatio }"
        @click="handlePreviewSlot(slot)"
      >
        <img
          v-if="slot.url && slot.status === 'success'"
          :src="imageSrc(slot.url)"
          alt=""
          :class="{ 'is-pending-src': !isImageReady(slot) }"
          @load="markImageReady(slot.key)"
          @error="markImageReady(slot.key)"
        />
        <span v-if="slot.status === 'failed' || !isImageReady(slot)" class="chat-generate-result-state">
          <span v-if="slot.status !== 'failed'" class="chat-generate-result-loader" aria-hidden="true">
            <span class="chat-generate-result-spin" />
          </span>
          {{ slot.status === "failed" ? "生成失败" : (slot.status === "pending" ? "生成中" : "加载中") }}
        </span>
      </button>
    </div>
    <p v-if="failedMessage && !isGenerating" class="chat-generate-error">{{ failedMessage }}</p>
    <div v-if="canEdit" class="chat-generate-actions">
      <span class="chat-generate-cost">预计 {{ estimatedCost }} 积分</span>
      <button type="button" class="chat-generate-cancel" :disabled="submitting" @click="handleCancel">取消</button>
      <button type="button" class="chat-generate-confirm" :disabled="submitting" @click="handleConfirm">
        {{ submitting ? "提交中…" : "确认生图" }}
      </button>
    </div>
    <div v-else-if="canRetry" class="chat-generate-actions">
      <span class="chat-generate-cost">预计 {{ estimatedCost }} 积分</span>
      <button type="button" class="chat-generate-confirm" :disabled="submitting" @click="handleRetry">
        {{ submitting ? "提交中…" : "重试" }}
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
  position: relative;
  width: 112px;
  height: auto;
  min-height: 112px;
  isolation: isolate;
  border-radius: 14px;
  border: 1px solid color-mix(in srgb, var(--theme-title, #3d2f22) 8%, transparent);
  background: color-mix(in srgb, var(--theme-title, #3d2f22) 4%, #fff);
}

.chat-generate-result.is-pending,
.chat-generate-result.is-loading {
  cursor: default;
  border-color: color-mix(in srgb, var(--theme-accent, #f7a831) 22%, var(--theme-panel-border, rgba(0, 0, 0, 0.08)));
  background:
    radial-gradient(120% 80% at 50% 12%, color-mix(in srgb, var(--theme-accent, #f7a831) 18%, transparent), transparent 56%),
    linear-gradient(180deg, color-mix(in srgb, var(--theme-panel-bg, #fff9f0) 88%, #fff), color-mix(in srgb, var(--theme-title, #3d2f22) 5%, #fff));
  box-shadow: inset 0 1px 0 color-mix(in srgb, #fff 72%, transparent);
}

.chat-generate-result.is-pending::before,
.chat-generate-result.is-loading::before {
  content: "";
  position: absolute;
  inset: -8% auto -8% -28%;
  width: 46%;
  pointer-events: none;
  background: linear-gradient(
    90deg,
    transparent 0%,
    color-mix(in srgb, #fff 58%, var(--theme-accent, #f7a831)) 48%,
    transparent 100%
  );
  opacity: 0.42;
  transform: translate3d(-30%, 0, 0);
  animation: chat-generate-shimmer 2.4s linear infinite;
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
  position: relative;
  z-index: 1;
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

.chat-generate-result.is-pending .chat-generate-result-state,
.chat-generate-result.is-loading .chat-generate-result-state {
  gap: 10px;
  color: var(--theme-title, #3d2f22);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.06em;
}

.chat-generate-result img.is-pending-src {
  position: absolute;
  inset: 0;
  opacity: 0;
  pointer-events: none;
}

.chat-generate-result.is-failed .chat-generate-result-state {
  color: #b42318;
}

.chat-generate-result-loader {
  position: relative;
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
}

.chat-generate-result-loader::before {
  content: "";
  position: absolute;
  inset: -7px;
  border-radius: 50%;
  background: radial-gradient(circle, color-mix(in srgb, var(--theme-accent, #f7a831) 34%, transparent), transparent 68%);
  animation: chat-generate-glow 1.8s ease-in-out infinite;
}

.chat-generate-result-spin {
  position: relative;
  width: 22px;
  height: 22px;
  border: 2px solid color-mix(in srgb, var(--theme-accent, #f7a831) 18%, transparent);
  border-top-color: var(--theme-accent, #f7a831);
  border-right-color: color-mix(in srgb, var(--theme-accent, #f7a831) 62%, transparent);
  border-radius: 50%;
  animation: chat-generate-spin 0.85s linear infinite;
}

@keyframes chat-generate-spin {
  to { transform: rotate(360deg); }
}

@keyframes chat-generate-shimmer {
  from { transform: translate3d(-30%, 0, 0); }
  to { transform: translate3d(260%, 0, 0); }
}

@keyframes chat-generate-glow {
  0%, 100% { opacity: 0.42; transform: scale(0.92); }
  50% { opacity: 0.9; transform: scale(1); }
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
