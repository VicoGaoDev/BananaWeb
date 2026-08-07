<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { message } from "ant-design-vue";
import { useRouter } from "vue-router";
import {
  CloseOutlined,
  CopyOutlined,
  DownloadOutlined,
  LeftOutlined,
  PictureOutlined,
  ReloadOutlined,
  RightOutlined,
  VideoCameraOutlined,
} from "@ant-design/icons-vue";
import dayjs from "dayjs";
import {
  exceedsRealtimeImagePreviewLimit,
  getPreviewImageSrc,
  getPreviewImageUrl,
  LARGE_IMAGE_PREVIEW_NOTICE,
  resolveImageUrl,
} from "@/api/images";
import { appendTransientImageNonce, useTransientImageLoad } from "@/composables/useTransientImageLoad";
import { withBaseUrl } from "@/lib/assets";
import { getTaskImageFailureMessage } from "@/lib/generationErrors";
import { saveImageToVideoDraft } from "@/lib/videoGenerateDraft";
import type { ImageResult, TaskApiAttempt, UserHistoryCard } from "@/types";

const SIDE_NAV_WIDTH = 76;
const SIDE_NAV_BREAKPOINT = 960;

const props = withDefaults(defineProps<{
  open: boolean;
  item: UserHistoryCard | null;
  preloadedMediaKeys?: string[];
  loading?: boolean;
  showActions?: boolean;
  showErrorMessage?: boolean;
  requestPreviewLoading?: boolean;
  hasPrev?: boolean;
  hasNext?: boolean;
  modelOptions?: Array<{ label: string; value: string }>;
  title?: string;
}>(), {
  preloadedMediaKeys: () => [],
  loading: false,
  showActions: false,
  showErrorMessage: false,
  requestPreviewLoading: false,
  hasPrev: false,
  hasNext: false,
  modelOptions: () => [],
  title: "任务详情",
});

const emit = defineEmits<{
  "update:open": [value: boolean];
  reedit: [item: UserHistoryCard];
  download: [item: UserHistoryCard];
  "navigate-prev": [];
  "navigate-next": [];
}>();

const previewVisible = ref(false);
const previewSrc = ref("");
const viewportWidth = ref(typeof window === "undefined" ? 1280 : window.innerWidth);
const loadedMediaKeys = ref<Set<string>>(new Set());
const requestPreviewActiveKeys = ref<string[]>([]);
const detailResultImageLoad = useTransientImageLoad();
const router = useRouter();
const failedResultAsset = withBaseUrl("failed-result.svg");
const generateTaskCardAsset = withBaseUrl("generate-task-card-minimal-a.svg");
const expiredResultAsset = `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(`
<svg xmlns="http://www.w3.org/2000/svg" width="960" height="960" viewBox="0 0 960 960">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#fff8ee"/>
      <stop offset="100%" stop-color="#ffe6c8"/>
    </linearGradient>
  </defs>
  <rect width="960" height="960" rx="56" fill="url(#bg)"/>
  <rect x="74" y="74" width="812" height="812" rx="42" fill="none" stroke="#efc784" stroke-dasharray="18 16" stroke-width="10"/>
  <g fill="none" stroke="#d08a24" stroke-linecap="round" stroke-linejoin="round">
    <rect x="282" y="248" width="396" height="286" rx="28" stroke-width="18"/>
    <path d="M326 490l110-108 92 88 72-66 76 86" stroke-width="18"/>
    <circle cx="400" cy="330" r="34" fill="#ffd585" stroke-width="12"/>
  </g>
  <text x="480" y="654" text-anchor="middle" font-size="54" font-weight="700" fill="#8c5a16">原图已过期</text>
  <text x="480" y="726" text-anchor="middle" font-size="34" fill="#a9742e">服务器只保留原图15天</text>
  <text x="480" y="776" text-anchor="middle" font-size="34" fill="#a9742e">请在有效期内查看或下载</text>
</svg>
`)}`;

const modelLabelMap = computed(() => new Map(props.modelOptions.map((item) => [item.value, item.label])));
const reserveSideNav = computed(() => {
  if (typeof document === "undefined") return false;
  if (viewportWidth.value <= SIDE_NAV_BREAKPOINT) return false;
  return !!document.querySelector(".app-layout-desktop-side-nav .canvas-side-nav");
});
const panelStyle = computed(() => (
  reserveSideNav.value
    ? { left: `${SIDE_NAV_WIDTH}px` }
    : { left: "0px" }
));
const detailErrorMessage = computed(() => (
  (props.item?.provider_error_message || props.item?.error_message || "").trim()
));
const requestPreviewAttempts = computed(() => (
  (props.item?.api_attempts || []).filter((attempt) => attempt.request_preview)
));
const showRequestPreviewSection = computed(() => (
  props.requestPreviewLoading || requestPreviewAttempts.value.length > 0
));

function updateViewportWidth() {
  if (typeof window === "undefined") return;
  viewportWidth.value = window.innerWidth;
}

function closeDialog() {
  emit("update:open", false);
}

function getDetailItemIdentity(item: UserHistoryCard | null | undefined) {
  if (!item) return "";
  // 与模板 detail-layout 的 :key 保持一致，避免 image_id 变化时清空已加载状态却不重挂载 img
  return String(item.display_id || item.task_id || item.history_id || item.image_id || item.created_at || "");
}

function seedLoadedMediaKeys(mode: "reset" | "merge" = "reset") {
  if (mode === "reset") {
    loadedMediaKeys.value = new Set(props.preloadedMediaKeys || []);
    return;
  }
  const next = new Set(loadedMediaKeys.value);
  for (const key of props.preloadedMediaKeys || []) {
    next.add(key);
  }
  loadedMediaKeys.value = next;
}

function navigatePrev() {
  if (!props.hasPrev) return;
  emit("navigate-prev");
}

function navigateNext() {
  if (!props.hasNext) return;
  emit("navigate-next");
}

function handleKeydown(event: KeyboardEvent) {
  if (!props.open) return;
  if (event.key === "Escape") {
    closeDialog();
    return;
  }
  if (event.key === "ArrowLeft") {
    event.preventDefault();
    navigatePrev();
    return;
  }
  if (event.key === "ArrowRight") {
    event.preventDefault();
    navigateNext();
  }
}

watch(
  () => [props.open, getDetailItemIdentity(props.item)] as const,
  ([open]) => {
    previewVisible.value = false;
    previewSrc.value = "";
    requestPreviewActiveKeys.value = [];
    seedLoadedMediaKeys("reset");
    detailResultImageLoad.dispose();
    if (typeof document === "undefined") return;
    document.body.style.overflow = open ? "hidden" : "";
  },
);

watch(
  () => props.preloadedMediaKeys,
  () => {
    seedLoadedMediaKeys("merge");
  },
  { deep: true },
);

watch(
  () => (props.item?.images || []).map((img) => {
    const key = getDetailBaseImageLoadKey(img);
    const source = props.item
      && img.status === "success"
      && !isHistoryItemExpired(props.item)
      && !shouldShowDetailLargeImagePreviewNotice(props.item, img)
      ? getDetailBaseImageResourceUrl(props.item, img)
      : "";
    return { key, source };
  }),
  (entries) => {
    const validKeys = new Set<string>();
    for (const entry of entries) {
      validKeys.add(entry.key);
      detailResultImageLoad.syncSource(entry.key, entry.source);
    }
    detailResultImageLoad.clearExcept(validKeys);
  },
  { immediate: true },
);

onMounted(() => {
  updateViewportWidth();
  if (typeof window !== "undefined") {
    window.addEventListener("resize", updateViewportWidth);
    window.addEventListener("keydown", handleKeydown);
  }
});

onBeforeUnmount(() => {
  detailResultImageLoad.dispose();
  if (typeof window !== "undefined") {
    window.removeEventListener("resize", updateViewportWidth);
    window.removeEventListener("keydown", handleKeydown);
  }
  if (typeof document !== "undefined") {
    document.body.style.overflow = "";
  }
});

function formatTime(t: string) {
  return t ? dayjs(t).format("YYYY-MM-DD HH:mm:ss") : "-";
}

function statusLabel(status: UserHistoryCard["status"]) {
  const mapping: Record<string, string> = {
    pending: "等待中",
    queued: "排队中",
    processing: "处理中",
    success: "成功",
    failed: "失败",
  };
  return mapping[status] || status;
}

function sourceLabel(source: UserHistoryCard["source"]) {
  if (source === "app") return "App";
  if (source === "api") return "API";
  return "Web";
}

function modeLabel(taskType: UserHistoryCard["task_type"]) {
  if (taskType === "text_generate") return "文生图";
  if (taskType === "image_edit") return "图编辑";
  if (taskType === "inpaint") return "局部重绘";
  if (taskType === "promptReverse") return "提示词反推";
  if (taskType === "promptOptimize") return "提示词优化";
  return taskType;
}

function getModelLabel(model?: string) {
  if (!model) return "-";
  return modelLabelMap.value.get(model) || model;
}

function formatImageSize(size?: number) {
  const bytes = Number(size || 0);
  if (!bytes) return "-";
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function detailMetaList(item: UserHistoryCard) {
  return [
    `状态：${statusLabel(item.status)}`,
    item.task_is_deleted ? "任务状态：已软删除" : "",
    item.is_soft_deleted ? `图片软删除：${item.images.filter((img) => img.is_deleted).length} 张` : "",
    `来源：${sourceLabel(item.source)}`,
    `类型：${modeLabel(item.task_type)}`,
    `模型：${getModelLabel(item.model)}`,
    item.style_name ? `风格：${item.style_name}` : "",
    `比例：${item.size || "-"}`,
    item.resolution ? `分辨率：${item.resolution}` : "",
    item.custom_size ? `自定义分辨率：${item.custom_size}` : "",
    item.image_format ? `格式：${item.image_format}` : "",
    item.image_size_bytes ? `大小：${formatImageSize(item.image_size_bytes)}` : "",
    item.item_type === "task" && item.api_attempts?.length
      ? `备用接口：${item.used_fallback_api ? "已调用" : "未调用"}`
      : "",
    item.run_time != null ? `接口调用耗时：${formatDuration((item.run_time || 0) * 1000)}` : "",
    item.request_started_at ? `开始时间：${formatTime(item.request_started_at)}` : "",
    item.request_finished_at ? `完成时间：${formatTime(item.request_finished_at)}` : "",
    `时间：${formatTime(item.created_at)}`,
  ].filter(Boolean);
}

function attemptStatusLabel(status: string) {
  return status === "success" ? "成功" : "失败";
}

function attemptRoleLabel(attempt: TaskApiAttempt) {
  return attempt.is_fallback ? "备用接口" : "主接口";
}

function attemptTargetLabel(attempt: TaskApiAttempt) {
  if (attempt.image_index && attempt.image_index > 0) return `第 ${attempt.image_index} 张结果图`;
  if (attempt.image_id) return `图片 #${attempt.image_id}`;
  return "任务级";
}

function formatDuration(durationMs?: number | null) {
  if (typeof durationMs !== "number" || Number.isNaN(durationMs)) return "-";
  if (durationMs < 1000) return `${durationMs} ms`;
  return `${(durationMs / 1000).toFixed(2)} s`;
}

function getCanvasAccessUrl(item: UserHistoryCard) {
  if (!item.canvas_project_id) return "";
  return `${window.location.origin}/canvas/${item.canvas_project_id}`;
}

function isHistoryItemExpired(item: Pick<UserHistoryCard, "created_at" | "status">) {
  if (item.status !== "success") return false;
  if (!item.created_at) return false;
  return dayjs().diff(dayjs(item.created_at), "day", true) >= 15;
}

function getNestedImageSrc(image: Pick<ImageResult, "thumb_url" | "image_url" | "preview_url" | "status">) {
  const displayUrl = getPreviewImageUrl(image);
  if (displayUrl) return displayUrl;
  return image.status === "failed" ? failedResultAsset : "";
}

function getNestedPreviewSrc(image: Pick<ImageResult, "thumb_url" | "image_url" | "preview_url">) {
  return getPreviewImageUrl(image);
}

function shouldShowDetailLargeImagePreviewNotice(item: UserHistoryCard, image: Pick<ImageResult, "status" | "image_size_bytes">) {
  return !isHistoryItemExpired(item) && image.status === "success" && exceedsRealtimeImagePreviewLimit(image.image_size_bytes);
}

function getDetailImageSrc(item: UserHistoryCard, image: Pick<ImageResult, "thumb_url" | "image_url" | "preview_url" | "status">) {
  if (isHistoryItemExpired(item) && image.status === "success") {
    return expiredResultAsset;
  }
  return getNestedImageSrc(image);
}

function getDetailBaseImageResourceUrl(item: UserHistoryCard, image: Pick<ImageResult, "thumb_url" | "image_url" | "preview_url" | "status" | "image_size_bytes">) {
  if (shouldShowDetailLargeImagePreviewNotice(item, image)) {
    return "";
  }
  if (image.thumb_url) return resolveImageUrl(image.thumb_url);
  return resolveImageUrl(image.preview_url || image.image_url || "");
}

function getDetailBaseImageLoadState(image: Pick<ImageResult, "id">) {
  return detailResultImageLoad.getState(getDetailBaseImageLoadKey(image));
}

function shouldShowDetailBaseUploadingState(item: UserHistoryCard, image: Pick<ImageResult, "id" | "thumb_url" | "image_url" | "preview_url" | "status" | "image_size_bytes">) {
  if (image.status !== "success") return false;
  if (isHistoryItemExpired(item)) return false;
  if (shouldShowDetailLargeImagePreviewNotice(item, image)) return false;
  const source = getDetailBaseImageResourceUrl(item, image);
  if (!source) return true;
  return getDetailBaseImageLoadState(image).phase === "retrying";
}

function shouldShowDetailBaseLoadFailedState(item: UserHistoryCard, image: Pick<ImageResult, "id" | "thumb_url" | "image_url" | "preview_url" | "status" | "image_size_bytes">) {
  if (image.status !== "success") return false;
  if (isHistoryItemExpired(item)) return false;
  if (shouldShowDetailLargeImagePreviewNotice(item, image)) return false;
  const source = getDetailBaseImageResourceUrl(item, image);
  if (!source) return false;
  return getDetailBaseImageLoadState(image).phase === "failed";
}

function getDetailBaseImageSrc(item: UserHistoryCard, image: Pick<ImageResult, "id" | "thumb_url" | "image_url" | "preview_url" | "status" | "image_size_bytes">) {
  if (isHistoryItemExpired(item) && image.status === "success") {
    return expiredResultAsset;
  }
  if (shouldShowDetailBaseLoadFailedState(item, image)) {
    return "";
  }
  const baseSource = getDetailBaseImageResourceUrl(item, image);
  if (baseSource) {
    return appendTransientImageNonce(baseSource, getDetailBaseImageLoadState(image).nonce);
  }
  return image.status === "failed" ? failedResultAsset : "";
}

function getDetailEnhancedImageSrc(item: UserHistoryCard, image: Pick<ImageResult, "id" | "thumb_url" | "image_url" | "preview_url" | "status" | "image_size_bytes">) {
  if (isHistoryItemExpired(item) && image.status === "success") {
    return expiredResultAsset;
  }
  if (shouldShowDetailLargeImagePreviewNotice(item, image)) {
    return "";
  }
  if (shouldShowDetailBaseUploadingState(item, image) || shouldShowDetailBaseLoadFailedState(item, image)) {
    return "";
  }
  const originalWebpUrl = getPreviewImageUrl({
    image_url: image.image_url || "",
    preview_url: image.preview_url || "",
    thumb_url: "",
  });
  if (originalWebpUrl) return originalWebpUrl;
  return getDetailBaseImageSrc(item, image);
}

function getDetailEnhancedImageLoadKey(image: Pick<ImageResult, "id">) {
  return getMediaLoadKey("detail-result-enhanced", image.id);
}

function getDetailBaseImageLoadKey(image: Pick<ImageResult, "id">) {
  return getMediaLoadKey("detail-result-base", image.id);
}

function getDetailPreviewSrc(item: UserHistoryCard, image: Pick<ImageResult, "thumb_url" | "image_url" | "preview_url" | "status" | "image_size_bytes">) {
  if (isHistoryItemExpired(item) && image.status === "success") {
    return "";
  }
  if (shouldShowDetailLargeImagePreviewNotice(item, image)) {
    return "";
  }
  return getNestedPreviewSrc(image);
}

function getDetailFailureMessage(item: UserHistoryCard, image: ImageResult) {
  return getTaskImageFailureMessage(item, image);
}

function getMediaLoadKey(prefix: string, value: string | number | null | undefined) {
  return `${prefix}:${String(value ?? "")}`;
}

function isMediaLoaded(key: string) {
  return loadedMediaKeys.value.has(key);
}

function markMediaLoaded(key: string) {
  if (!key || loadedMediaKeys.value.has(key)) return;
  const next = new Set(loadedMediaKeys.value);
  next.add(key);
  loadedMediaKeys.value = next;
}

function bindDetailMediaEl(el: unknown, key: string) {
  if (!(el instanceof HTMLImageElement) || !key) return;
  // 缓存命中时部分浏览器可能不再触发 @load，这里补齐已完成图片的可见状态
  if (el.complete && el.naturalWidth > 0) {
    markMediaLoaded(key);
  }
}

function openPreview(url: string) {
  if (!url) return;
  previewSrc.value = url;
  previewVisible.value = true;
}

function handleDetailImageError(event: Event, key?: string) {
  if (key) markMediaLoaded(key);
  if (!props.item || !isHistoryItemExpired(props.item)) return;
  const image = event.target as HTMLImageElement;
  if (image.dataset.expiredFallback === "true") return;
  image.dataset.expiredFallback = "true";
  image.classList.add("detail-expired-image");
  image.src = expiredResultAsset;
}

function handleDetailResultImageError(item: UserHistoryCard, image: Pick<ImageResult, "id" | "thumb_url" | "image_url" | "preview_url" | "status" | "image_size_bytes">) {
  if (image.status !== "success" || isHistoryItemExpired(item)) return;
  if (shouldShowDetailLargeImagePreviewNotice(item, image)) return;
  const source = getDetailBaseImageResourceUrl(item, image);
  if (!source) return;
  detailResultImageLoad.scheduleRetry(getDetailBaseImageLoadKey(image), source);
}

async function copyPrompt(text?: string) {
  if (!text?.trim()) return;
  try {
    await navigator.clipboard.writeText(text);
    message.success("已复制提示词");
  } catch {
    message.error("复制失败，请重试");
  }
}

function stringifyRequestPayload(payload: unknown) {
  if (payload == null) return "{}";
  try {
    return JSON.stringify(payload, null, 2);
  } catch {
    return String(payload);
  }
}

function stringifyRequestHeaders(headers?: Record<string, string>) {
  return JSON.stringify(headers || {}, null, 2);
}

function shellQuote(value: string) {
  return `'${String(value || "").replace(/'/g, "'\\''")}'`;
}

function buildRequestCurl(preview: NonNullable<TaskApiAttempt["request_preview"]>) {
  const lines = [`curl ${preview.request_url || ""}`];
  Object.entries(preview.headers || {}).forEach(([name, value]) => {
    lines.push(`  -H ${shellQuote(`${name}: ${value}`)}`);
  });
  lines.push(`  -d ${shellQuote(stringifyRequestPayload(preview.payload))}`);
  return lines.join(" \\\n");
}

async function copyRequestText(text: string, successMessage: string) {
  if (!text.trim()) return;
  try {
    await navigator.clipboard.writeText(text);
    message.success(successMessage);
  } catch {
    message.error("复制失败，请重试");
  }
}

function handleReedit(item: UserHistoryCard) {
  emit("reedit", item);
}

function handleDownload(item: UserHistoryCard) {
  emit("download", item);
}

function canGenerateVideoFromDetailItem(item: UserHistoryCard) {
  if (item.item_type !== "task" || item.mode === "promptReverse" || item.status !== "success") return false;
  if (isHistoryItemExpired(item)) return false;
  return Boolean(item.image_url || item.preview_url || item.thumb_url);
}

function handleGenerateVideo(item: UserHistoryCard) {
  const referenceImage = item.image_url || item.preview_url || item.thumb_url || "";
  if (!referenceImage) {
    message.warning("当前结果图暂不可用于生成视频");
    return;
  }
  if (!saveImageToVideoDraft({ referenceImage, prompt: item.prompt || "" })) {
    message.warning("当前结果图暂不可用于生成视频");
    return;
  }
  router.push("/video-generate");
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="open"
      class="history-task-detail-overlay"
      :class="{ 'is-side-nav-offset': reserveSideNav }"
      :style="panelStyle"
    >
      <div class="history-task-detail-panel">
        <div class="history-task-detail-header">
          <div class="history-task-detail-title">{{ title }}</div>
          <button type="button" class="history-task-detail-close" aria-label="关闭" @click="closeDialog">
            <CloseOutlined />
          </button>
        </div>

        <div class="history-task-detail-body">
          <div v-if="loading" class="detail-loading">
            <span>正在加载任务详情...</span>
          </div>
          <template v-else-if="item">
            <div :key="item.display_id || item.task_id || item.history_id || item.image_id || item.created_at" class="detail-layout">
              <div class="detail-left">
                <button
                  v-if="hasPrev"
                  type="button"
                  class="detail-nav-btn detail-nav-prev"
                  aria-label="上一个任务"
                  @click="navigatePrev"
                >
                  <LeftOutlined />
                </button>
                <button
                  v-if="hasNext"
                  type="button"
                  class="detail-nav-btn detail-nav-next"
                  aria-label="下一个任务"
                  @click="navigateNext"
                >
                  <RightOutlined />
                </button>
                <div class="detail-section">
                  <div v-if="item.mode === 'promptReverse'" class="detail-label">反推原图</div>
                  <div v-if="item.mode === 'promptReverse' && item.source_image" class="detail-thumb-row">
                    <div
                      class="detail-thumb detail-thumb-large"
                      @click="!isHistoryItemExpired(item) && openPreview(getPreviewImageSrc(item.source_image))"
                    >
                      <div
                        v-if="!isMediaLoaded(getMediaLoadKey('prompt-reverse-source', item.source_image_thumb || item.source_image))"
                        class="detail-media-loading"
                      />
                      <img
                        :ref="(el) => bindDetailMediaEl(el, getMediaLoadKey('prompt-reverse-source', item?.source_image_thumb || item?.source_image))"
                        :src="isHistoryItemExpired(item) ? expiredResultAsset : getPreviewImageSrc(item.source_image_thumb || item.source_image)"
                        alt="提示词反推原图"
                        loading="lazy"
                        :class="{ 'detail-media-hidden': !isMediaLoaded(getMediaLoadKey('prompt-reverse-source', item?.source_image_thumb || item?.source_image)) }"
                        @load="markMediaLoaded(getMediaLoadKey('prompt-reverse-source', item?.source_image_thumb || item?.source_image))"
                        @error="(event) => handleDetailImageError(event, getMediaLoadKey('prompt-reverse-source', item?.source_image_thumb || item?.source_image))"
                      />
                    </div>
                  </div>
                  <div v-else class="detail-result-grid" :class="{ 'is-single': item.images.length === 1 }">
                    <div
                      v-for="img in item.images"
                      :key="img.id"
                      class="detail-result-card"
                      :class="{
                        single: item.images.length === 1,
                        pending: !getDetailBaseImageSrc(item, img) && !getDetailEnhancedImageSrc(item, img) && img.status !== 'failed',
                        failed: img.status === 'failed',
                      }"
                      :style="{ '--detail-pending-bg-image': `url('${generateTaskCardAsset}')` }"
                      @click="getDetailPreviewSrc(item, img) && openPreview(getDetailPreviewSrc(item, img))"
                    >
                      <div
                        v-if="!shouldShowDetailLargeImagePreviewNotice(item, img) && !shouldShowDetailBaseUploadingState(item, img) && !shouldShowDetailBaseLoadFailedState(item, img) && !getDetailBaseImageSrc(item, img) && !isMediaLoaded(getDetailEnhancedImageLoadKey(img))"
                        class="detail-media-loading"
                      />
                      <img
                        v-if="getDetailBaseImageSrc(item, img) || img.status === 'failed'"
                        :src="getDetailBaseImageSrc(item, img) || failedResultAsset"
                        :alt="img.status === 'failed' ? '生成失败' : '结果图'"
                        class="detail-result-image-base"
                        :class="{ 'failed-result-image': img.status === 'failed' }"
                        loading="lazy"
                        @load="markMediaLoaded(getDetailBaseImageLoadKey(img))"
                        @error="handleDetailResultImageError(item, img)"
                      />
                      <img
                        v-if="getDetailEnhancedImageSrc(item, img) && getDetailEnhancedImageSrc(item, img) !== getDetailBaseImageSrc(item, img)"
                        :src="getDetailEnhancedImageSrc(item, img)"
                        :alt="img.status === 'failed' ? '生成失败' : '结果图'"
                        class="detail-result-image-enhanced"
                        :class="{ 'failed-result-image': img.status === 'failed', 'detail-media-hidden': !isMediaLoaded(getDetailEnhancedImageLoadKey(img)) }"
                        loading="lazy"
                        @load="markMediaLoaded(getDetailEnhancedImageLoadKey(img))"
                        @error="() => markMediaLoaded(getDetailEnhancedImageLoadKey(img))"
                      />
                      <div v-if="img.status === 'failed'" class="detail-failure-message">
                        {{ getDetailFailureMessage(item, img) }}
                      </div>
                      <div v-else-if="shouldShowDetailLargeImagePreviewNotice(item, img)" class="detail-preview-notice">
                        <span>{{ LARGE_IMAGE_PREVIEW_NOTICE }}</span>
                      </div>
                      <div v-else-if="shouldShowDetailBaseUploadingState(item, img)" class="result-card-placeholder">
                        <span>图片加载中...</span>
                      </div>
                      <div v-else-if="shouldShowDetailBaseLoadFailedState(item, img)" class="result-card-placeholder">
                        <span>图片加载较慢，请稍后重试</span>
                      </div>
                      <div v-else-if="!getDetailBaseImageSrc(item, img) && !getDetailEnhancedImageSrc(item, img)" class="result-card-placeholder">
                        <span>图片处理中...</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="detail-right">
                <div v-if="item.task_is_deleted || item.is_soft_deleted" class="detail-section">
                  <div class="detail-alert-list">
                    <div v-if="item.task_is_deleted" class="detail-alert detail-alert-danger">
                      该任务已被用户软删除，仅在后台历史记录中保留展示。
                    </div>
                    <div v-if="item.is_soft_deleted" class="detail-alert detail-alert-warning">
                      该任务存在已软删图片，当前详情默认仅展示未删除图片。
                    </div>
                  </div>
                </div>

                <div class="detail-section">
                  <div class="detail-meta">
                    <span v-for="meta in detailMetaList(item)" :key="meta">{{ meta }}</span>
                  </div>
                  <div v-if="getCanvasAccessUrl(item)" class="detail-canvas-link-row">
                    <span class="detail-canvas-link-label">Canvas 访问地址：</span>
                    <a
                      class="detail-canvas-link"
                      :href="getCanvasAccessUrl(item)"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {{ getCanvasAccessUrl(item) }}
                    </a>
                  </div>
                </div>

                <div v-if="item.mode === 'inpaint' && item.source_image" class="detail-section">
                  <div class="detail-label">局部重绘原图</div>
                  <div class="detail-thumb-row">
                    <div class="detail-thumb" @click="!isHistoryItemExpired(item) && openPreview(getPreviewImageSrc(item.source_image))">
                      <div
                        v-if="!isMediaLoaded(getMediaLoadKey('inpaint-source', item.source_image_thumb || item.source_image))"
                        class="detail-media-loading"
                      />
                      <img
                        :ref="(el) => bindDetailMediaEl(el, getMediaLoadKey('inpaint-source', item?.source_image_thumb || item?.source_image))"
                        :src="isHistoryItemExpired(item) ? expiredResultAsset : getPreviewImageSrc(item.source_image_thumb || item.source_image)"
                        alt="局部重绘原图"
                        loading="lazy"
                        :class="{ 'detail-media-hidden': !isMediaLoaded(getMediaLoadKey('inpaint-source', item?.source_image_thumb || item?.source_image)) }"
                        @load="markMediaLoaded(getMediaLoadKey('inpaint-source', item?.source_image_thumb || item?.source_image))"
                        @error="(event) => handleDetailImageError(event, getMediaLoadKey('inpaint-source', item?.source_image_thumb || item?.source_image))"
                      />
                    </div>
                  </div>
                </div>

                <div v-if="item.reference_images.length" class="detail-section">
                  <div class="detail-label">
                    <PictureOutlined />
                    <span>参考图</span>
                  </div>
                  <div class="detail-thumb-row">
                    <div
                      v-for="(ref, index) in item.reference_images"
                      :key="index"
                      class="detail-thumb"
                      @click="openPreview(getPreviewImageSrc(ref))"
                    >
                      <div
                        v-if="!isMediaLoaded(getMediaLoadKey('reference-image', `${index}-${ref}`))"
                        class="detail-media-loading"
                      />
                      <img
                        :ref="(el) => bindDetailMediaEl(el, getMediaLoadKey('reference-image', `${index}-${ref}`))"
                        :src="getPreviewImageSrc(item.reference_image_thumbs[index] || ref)"
                        alt="参考图"
                        loading="lazy"
                        :class="{ 'detail-media-hidden': !isMediaLoaded(getMediaLoadKey('reference-image', `${index}-${ref}`)) }"
                        @load="markMediaLoaded(getMediaLoadKey('reference-image', `${index}-${ref}`))"
                        @error="(event) => handleDetailImageError(event, getMediaLoadKey('reference-image', `${index}-${ref}`))"
                      />
                    </div>
                  </div>
                </div>

                <div class="detail-section">
                  <div class="detail-label-row">
                    <div class="detail-label">提示词</div>
                    <a-button type="text" class="detail-copy-btn" @click="copyPrompt(item.prompt)">
                      <template #icon><CopyOutlined /></template>
                      复制提示词
                    </a-button>
                  </div>
                  <div class="detail-prompt">{{ item.prompt || "-" }}</div>
                  <div v-if="showErrorMessage && detailErrorMessage" class="detail-error-block">
                    <div class="detail-error-label">错误信息</div>
                    <div class="detail-error-message">{{ detailErrorMessage }}</div>
                  </div>
                  <div v-if="item.api_attempts?.length" class="detail-attempt-section">
                    <div class="detail-label detail-attempt-section-title">接口调用记录</div>
                    <div class="detail-attempt-list">
                      <div v-for="attempt in item.api_attempts" :key="`${attempt.id || 'attempt'}-${attempt.image_id || 0}-${attempt.attempt_index}`" class="detail-attempt-card">
                        <div class="detail-attempt-header">
                          <span class="detail-attempt-title">{{ attemptTargetLabel(attempt) }}</span>
                          <a-space size="small">
                            <a-tag class="api-tag" :class="attempt.is_fallback ? 'api-tag-group' : 'api-tag-muted'">
                              {{ attemptRoleLabel(attempt) }}
                            </a-tag>
                            <a-tag class="api-tag" :class="attempt.status === 'success' ? 'api-tag-enabled' : 'api-tag-danger'">
                              {{ attemptStatusLabel(attempt.status) }}
                            </a-tag>
                          </a-space>
                        </div>
                        <div class="detail-attempt-meta">
                          <span>第 {{ attempt.attempt_index }} 次尝试</span>
                          <span>接口：{{ attempt.api_config_name || "-" }}</span>
                          <span>HTTP：{{ typeof attempt.http_status === "number" ? attempt.http_status : "-" }}</span>
                          <span>耗时：{{ formatDuration(attempt.duration_ms) }}</span>
                        </div>
                        <div v-if="attempt.error_message" class="detail-attempt-error">{{ attempt.error_message }}</div>
                      </div>
                    </div>
                  </div>
                  <div v-if="showRequestPreviewSection" class="detail-request-preview-section">
                    <div class="detail-label-row detail-request-preview-title-row">
                      <div class="detail-label">接口调用参数</div>
                      <a-spin v-if="requestPreviewLoading" size="small" />
                    </div>
                    <div v-if="requestPreviewLoading" class="detail-request-loading">正在加载可复制的接口调用参数...</div>
                    <a-collapse
                      v-else
                      v-model:activeKey="requestPreviewActiveKeys"
                      ghost
                      class="detail-request-collapse"
                    >
                      <a-collapse-panel
                        v-for="attempt in requestPreviewAttempts"
                        :key="String(attempt.id || `${attempt.image_id || 0}-${attempt.attempt_index}`)"
                        :header="`${attemptTargetLabel(attempt)} · ${attemptRoleLabel(attempt)} · 第 ${attempt.attempt_index} 次尝试`"
                      >
                        <template v-if="attempt.request_preview">
                          <div class="detail-request-preview">
                            <div class="detail-request-preview-head">
                              <span>{{ attempt.api_config_name || "绑定接口" }}</span>
                            </div>
                            <div class="detail-request-field">
                              <div class="detail-request-field-head">
                                <div class="detail-request-label">URL</div>
                                <a-tooltip title="复制 URL">
                                  <a-button
                                    size="small"
                                    type="text"
                                    class="detail-request-copy-icon"
                                    @click="copyRequestText(attempt.request_preview.request_url || '', '已复制 URL')"
                                  >
                                    <template #icon><CopyOutlined /></template>
                                  </a-button>
                                </a-tooltip>
                              </div>
                              <pre>{{ attempt.request_preview.request_url || "-" }}</pre>
                            </div>
                            <div class="detail-request-field">
                              <div class="detail-request-field-head">
                                <div class="detail-request-label">Header</div>
                                <a-tooltip title="复制 Header">
                                  <a-button
                                    size="small"
                                    type="text"
                                    class="detail-request-copy-icon"
                                    @click="copyRequestText(stringifyRequestHeaders(attempt.request_preview.headers), '已复制 Header')"
                                  >
                                    <template #icon><CopyOutlined /></template>
                                  </a-button>
                                </a-tooltip>
                              </div>
                              <pre>{{ stringifyRequestHeaders(attempt.request_preview.headers) }}</pre>
                            </div>
                            <div class="detail-request-field">
                              <div class="detail-request-field-head">
                                <div class="detail-request-label">参数 JSON</div>
                                <a-tooltip title="复制参数 JSON">
                                  <a-button
                                    size="small"
                                    type="text"
                                    class="detail-request-copy-icon"
                                    @click="copyRequestText(stringifyRequestPayload(attempt.request_preview.payload), '已复制参数 JSON')"
                                  >
                                    <template #icon><CopyOutlined /></template>
                                  </a-button>
                                </a-tooltip>
                              </div>
                              <pre>{{ stringifyRequestPayload(attempt.request_preview.payload) }}</pre>
                            </div>
                            <div class="detail-request-field">
                              <div class="detail-request-field-head">
                                <div class="detail-request-label">curl</div>
                                <a-tooltip title="复制 curl">
                                  <a-button
                                    size="small"
                                    type="text"
                                    class="detail-request-copy-icon"
                                    @click="copyRequestText(buildRequestCurl(attempt.request_preview), '已复制 curl')"
                                  >
                                    <template #icon><CopyOutlined /></template>
                                  </a-button>
                                </a-tooltip>
                              </div>
                              <pre>{{ buildRequestCurl(attempt.request_preview) }}</pre>
                            </div>
                          </div>
                        </template>
                      </a-collapse-panel>
                    </a-collapse>
                  </div>
                </div>
              </div>

              <div v-if="showActions" class="detail-floating-actions">
                <a-tooltip v-if="canGenerateVideoFromDetailItem(item)" title="生成视频">
                  <a-button type="text" class="ghost-icon-btn detail-action-btn" @click="handleGenerateVideo(item)">
                    <template #icon><VideoCameraOutlined /></template>
                  </a-button>
                </a-tooltip>
                <a-tooltip title="重新编辑">
                  <a-button type="text" class="ghost-icon-btn detail-action-btn" @click="handleReedit(item)">
                    <template #icon><ReloadOutlined /></template>
                  </a-button>
                </a-tooltip>
                <a-tooltip title="下载原图">
                  <a-button
                    type="text"
                    class="ghost-icon-btn detail-action-btn"
                    :disabled="isHistoryItemExpired(item) || !item.image_url || typeof item.image_id !== 'number'"
                    @click="handleDownload(item)"
                  >
                    <template #icon><DownloadOutlined /></template>
                  </a-button>
                </a-tooltip>
              </div>
            </div>
          </template>
        </div>
      </div>
    </div>
  </Teleport>

  <div v-if="previewVisible" style="display: none">
    <a-image
      :src="previewSrc"
      :preview="{ visible: previewVisible, onVisibleChange: (v: boolean) => (previewVisible = v) }"
    />
  </div>
</template>

<style scoped lang="scss">
.history-task-detail-overlay {
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  z-index: 1000;
  display: flex;
  flex-direction: column;
  background: var(--theme-panel-bg, #fffaf2);
}

.history-task-detail-panel {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
}

.history-task-detail-header {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 24px;
  border-bottom: 1px solid var(--theme-panel-border);
  background: var(--theme-modal-header-bg, #fff8ec);
}

.history-task-detail-title {
  color: var(--theme-title);
  font-size: 16px;
  font-weight: 700;
  line-height: 1.4;
}

.history-task-detail-close {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  margin: 0;
  padding: 0;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  transition:
    color var(--motion-duration-fast) var(--motion-ease-soft),
    background var(--motion-duration-fast) var(--motion-ease-soft);

  &:hover {
    color: var(--theme-title);
    background: rgba(var(--theme-surface-strong-rgb), 0.72);
  }
}

.history-task-detail-body {
  flex: 1 1 auto;
  min-height: 0;
  display: flex;
  flex-direction: column;
  padding: 20px 24px 24px 0;
  overflow: hidden;
}

.detail-loading {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding-left: 24px;
  color: var(--text-secondary);
}

@keyframes history-detail-slide-in {
  from {
    opacity: 0;
    transform: translate3d(22px, 0, 0) scale(0.985);
  }
  to {
    opacity: 1;
    transform: translate3d(0, 0, 0) scale(1);
  }
}

.detail-section + .detail-section {
  margin-top: 18px;
}

.detail-attempt-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.detail-attempt-section {
  margin-top: 12px;
}

.detail-attempt-section-title {
  margin-bottom: 8px;
}

.detail-attempt-card {
  border: 1px solid var(--border-color);
  border-radius: 14px;
  padding: 12px 14px;
  background: var(--bg-elevated, rgba(255, 255, 255, 0.64));
}

.detail-attempt-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.detail-attempt-title {
  font-weight: 600;
  color: var(--text-primary);
}

.detail-attempt-meta {
  margin-top: 8px;
  display: flex;
  flex-wrap: wrap;
  gap: 8px 14px;
  color: var(--text-secondary);
  font-size: 13px;
}

.detail-attempt-error {
  margin-top: 8px;
  color: var(--danger-color, #d84f45);
  font-size: 13px;
  line-height: 1.6;
  white-space: pre-wrap;
}

.detail-request-preview {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.detail-request-preview-section {
  margin-top: 12px;
}

.detail-request-preview-title-row {
  margin-bottom: 8px;
}

.detail-request-loading {
  display: flex;
  align-items: center;
  min-height: 38px;
  padding: 9px 12px;
  border: 1px dashed var(--theme-panel-border);
  border-radius: 12px;
  background: var(--theme-panel-bg-soft);
  color: var(--theme-text-secondary);
  font-size: 12px;
}

.detail-request-collapse {
  border: 1px solid var(--theme-panel-border);
  border-radius: 12px;
  background: var(--theme-panel-bg-soft);
}

.detail-request-collapse :deep(.ant-collapse-item) {
  border-bottom: 1px solid var(--theme-panel-border);
}

.detail-request-collapse :deep(.ant-collapse-item:last-child) {
  border-bottom: 0;
}

.detail-request-collapse :deep(.ant-collapse-header) {
  align-items: center;
  padding: 10px 12px !important;
  color: var(--theme-title) !important;
  font-size: 12px;
  font-weight: 700;
}

.detail-request-collapse :deep(.ant-collapse-content-box) {
  padding: 0 12px 12px !important;
}

.detail-request-preview-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  color: var(--theme-title);
  font-size: 13px;
  font-weight: 700;
}

.detail-request-field-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 6px;
}

.detail-request-label {
  color: var(--theme-text-secondary);
  font-size: 12px;
  font-weight: 700;
}

.detail-request-copy-icon {
  width: 26px;
  height: 26px;
  padding: 0;
  border-radius: 8px;
  color: var(--theme-link) !important;
}

.detail-request-copy-icon:hover {
  background: var(--theme-control-hover-bg) !important;
  color: var(--theme-accent-text-hover) !important;
}

.detail-request-field pre {
  max-height: 220px;
  margin: 0;
  padding: 10px 12px;
  overflow: auto;
  border: 1px solid var(--theme-panel-border);
  border-radius: 10px;
  background: rgba(17, 24, 39, 0.04);
  color: var(--theme-title);
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
  font-size: 12px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
  scrollbar-width: thin;
}

.api-tag-danger {
  color: #b42318;
  background: rgba(217, 45, 32, 0.12);
}

.detail-layout {
  position: relative;
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) minmax(280px, 0.55fr);
  gap: 0;
  align-items: stretch;
  flex: 1 1 auto;
  min-height: 0;
  height: 100%;
  animation: history-detail-slide-in var(--motion-duration-reveal-slower) var(--motion-ease-enter) both;
}

.detail-left,
.detail-right {
  min-width: 0;
  min-height: 0;
}

.detail-left {
  position: relative;
  display: flex;
  flex-direction: column;
  padding-left: 56px;
  padding-right: 56px;
}

.detail-nav-btn {
  position: absolute;
  top: 50%;
  z-index: 4;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  margin: 0;
  padding: 0;
  border: 1px solid var(--theme-panel-border);
  border-radius: 999px;
  background: rgba(var(--theme-surface-strong-rgb), 0.92);
  color: var(--theme-title);
  box-shadow: 0 10px 24px var(--theme-shadow-soft);
  cursor: pointer;
  transform: translateY(-50%);
  transition:
    color var(--motion-duration-fast) var(--motion-ease-soft),
    background var(--motion-duration-fast) var(--motion-ease-soft),
    border-color var(--motion-duration-fast) var(--motion-ease-soft),
    box-shadow var(--motion-duration-fast) var(--motion-ease-soft),
    transform var(--motion-duration-fast) var(--motion-ease-soft);

  &:hover {
    color: var(--theme-accent-text);
    border-color: var(--theme-border-strong);
    background: var(--theme-panel-bg);
    box-shadow: 0 14px 28px var(--theme-shadow-soft);
    transform: translateY(calc(-50% - 1px));
  }
}

.detail-nav-prev {
  left: 8px;
}

.detail-nav-next {
  right: 8px;
}

.detail-left > .detail-section {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  margin-top: 0;
}

.detail-right {
  display: flex;
  flex-direction: column;
  max-height: 100%;
  overflow-x: hidden;
  overflow-y: auto;
  padding-left: 20px;
  padding-right: 4px;
  padding-bottom: 44px;
  border-left: 1px solid var(--theme-panel-border);
  scrollbar-width: thin;
}

.detail-alert-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.detail-alert {
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px solid transparent;
  font-size: 13px;
  line-height: 1.7;
}

.detail-canvas-link-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 10px;
  font-size: 12px;
  line-height: 1.5;
}

.detail-canvas-link-label {
  color: var(--theme-text-secondary);
}

.detail-canvas-link {
  color: var(--theme-accent-text);
  word-break: break-all;
}

.detail-canvas-link:hover {
  color: var(--theme-accent-text-hover);
}

.detail-alert-danger {
  border-color: rgba(214, 87, 75, 0.22);
  background: rgba(255, 240, 237, 0.96);
  color: #bf5548;
}

.detail-alert-warning {
  border-color: rgba(255, 171, 37, 0.22);
  background: rgba(255, 248, 232, 0.96);
  color: #9b6a1f;
}

.detail-action-btn {
  width: 36px;
  height: 36px;
}

.detail-floating-actions {
  position: absolute;
  right: 0;
  bottom: 0;
  display: flex;
  gap: 6px;
  padding: 0 2px 2px 0;
}

.detail-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 700;
  color: var(--text-secondary);
}

.detail-section > .detail-label {
  margin-bottom: 10px;
}

.detail-label-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 10px;
}

.detail-copy-btn {
  height: 30px;
  padding-inline: 10px;
  border-radius: 10px;
  color: var(--theme-link) !important;
}

.detail-prompt {
  padding: 12px 14px;
  border-radius: 12px;
  background: var(--theme-panel-bg-soft);
  border: 1px solid var(--theme-panel-border);
  color: var(--theme-title);
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
  max-height: 280px;
  overflow-y: auto;
  scrollbar-width: thin;
}

.detail-error-block {
  margin-top: 12px;
}

.detail-error-label {
  margin-bottom: 8px;
  color: #b85d47;
  font-size: 13px;
  font-weight: 700;
}

.detail-error-message {
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px solid rgba(207, 63, 54, 0.16);
  background: rgba(255, 242, 239, 0.92);
  color: #b85d47;
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

.detail-thumb-row {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.detail-thumb {
  position: relative;
  width: 84px;
  height: 84px;
  border-radius: 12px;
  overflow: hidden;
  border: 1px solid var(--theme-panel-border);
  background: var(--theme-panel-bg-soft);
  cursor: pointer;
  transition:
    transform var(--motion-duration-base) var(--motion-ease-soft),
    box-shadow var(--motion-duration-base) var(--motion-ease-soft),
    border-color var(--motion-duration-base) var(--motion-ease-soft);

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  &:hover {
    transform: translateY(-2px);
    border-color: var(--theme-border-strong);
    box-shadow: 0 16px 24px var(--theme-shadow-soft);
  }
}

.detail-thumb-large {
  width: 100%;
  height: auto;
  max-height: 100%;
  aspect-ratio: 1 / 1;
  border-radius: 0;
  border: 0;
  background: transparent;

  &:hover {
    transform: none;
    box-shadow: none;
  }
}

.detail-result-grid {
  flex: 1;
  min-height: 0;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 14px;
  align-content: stretch;

  &.is-single {
    grid-template-columns: 1fr;
  }
}

.detail-result-card {
  min-height: 0;
  height: 100%;
  border-radius: 0;
  overflow: hidden;
  border: 0;
  background: transparent;
  position: relative;
  cursor: pointer;

  img,
  .result-card-placeholder {
    width: 100%;
    height: 100%;
  }

  img {
    position: absolute;
    inset: 0;
    object-fit: contain;
    display: block;
    background: var(--theme-panel-bg);
  }

  &.pending {
    cursor: default;
    background:
      linear-gradient(180deg, rgba(255, 252, 246, 0.24), rgba(255, 248, 238, 0.34)),
      linear-gradient(180deg, var(--theme-panel-bg-soft), var(--theme-panel-bg));
  }

  &.pending::before {
    content: "";
    position: absolute;
    inset: 0;
    background: var(--detail-pending-bg-image) center / cover no-repeat;
    opacity: 0.5;
    pointer-events: none;
  }

  &.failed img {
    object-fit: contain;
    padding: 18px;
    background: var(--theme-panel-bg);
  }

  &.single {
    height: 100%;
  }
}

.detail-result-image-base {
  z-index: 1;
}

.detail-result-image-enhanced {
  z-index: 2;
  transition: opacity var(--motion-duration-base, 0.2s) var(--motion-ease-soft, ease);
}

.detail-media-loading {
  position: absolute;
  inset: 0;
  z-index: 2;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(180deg, rgba(255, 252, 246, 0.82), rgba(255, 248, 238, 0.88));
}

.detail-media-hidden {
  opacity: 0;
}

.result-card-placeholder {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  color: var(--theme-text-primary);
  text-align: center;
  font-size: 15px;
  line-height: 1.6;
  font-weight: 600;
  background: linear-gradient(180deg, var(--theme-panel-bg-soft), var(--theme-panel-bg));

  span {
    max-width: min(100%, 240px);
    padding: 10px 14px;
    border-radius: 12px;
    background: rgba(var(--theme-surface-strong-rgb), 0.84);
    box-shadow: 0 8px 18px rgba(76, 52, 26, 0.1);
  }
}

.detail-preview-notice {
  position: relative;
  z-index: 3;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  color: #6f4d1f;
  text-align: center;
  font-size: 15px;
  line-height: 1.75;
  font-weight: 600;
  background:
    linear-gradient(180deg, rgba(255, 249, 241, 0.94), rgba(255, 245, 232, 0.98)),
    linear-gradient(180deg, var(--theme-panel-bg-soft), var(--theme-panel-bg));

  span {
    max-width: min(100%, 320px);
    padding: 12px 16px;
    border-radius: 14px;
    background: rgba(255, 252, 247, 0.98);
    border: 1px solid rgba(201, 160, 102, 0.22);
    box-shadow: 0 12px 28px rgba(76, 52, 26, 0.14);
  }
}

.failed-result-image {
  object-fit: contain !important;
  padding: 28px;
  background: linear-gradient(180deg, #fff2ef, #ffdcd5);
  opacity: 0.96;
}

.detail-expired-image {
  object-fit: contain !important;
  padding: 28px;
  background: #fff8ee;
}

.detail-failure-message {
  position: absolute;
  left: 14px;
  right: 14px;
  bottom: 14px;
  z-index: 4;
  padding: 0;
  color: #b42318;
  font-size: 14px;
  line-height: 1.55;
  font-weight: 700;
  text-shadow: 0 1px 2px rgba(255, 248, 247, 0.95);
  pointer-events: none;
}

.detail-meta {
  display: flex;
  flex-wrap: wrap;
  padding: 12px 14px;
  border-radius: 12px;
  background: var(--theme-panel-bg-soft);
  border: 1px solid var(--theme-panel-border);
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.8;

  span:not(:last-child)::after {
    content: "｜";
    margin: 0 8px;
    color: #d3b487;
  }
}

@media (prefers-reduced-motion: reduce) {
  .detail-layout,
  .detail-thumb,
  .detail-result-card {
    animation: none !important;
    transition: none !important;
  }
}

@media (max-width: 960px) {
  .detail-layout {
    grid-template-columns: 1fr;
    grid-template-rows: minmax(240px, 42vh) minmax(0, 1fr);
    overflow: hidden;
  }

  .detail-left {
    padding-left: 48px;
    padding-right: 48px;
    padding-bottom: 16px;
  }

  .detail-nav-prev {
    left: 4px;
  }

  .detail-nav-next {
    right: 4px;
  }

  .detail-right {
    max-height: none;
    overflow: auto;
    padding-left: 0;
    padding-right: 0;
    padding-top: 16px;
    border-left: 0;
    border-top: 1px solid var(--theme-panel-border);
  }

  .detail-floating-actions {
    position: static;
    justify-content: flex-end;
    margin-top: 14px;
    padding: 0;
  }
}
</style>
