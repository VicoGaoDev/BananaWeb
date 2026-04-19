<script setup lang="ts">
import { computed, ref, onMounted, onBeforeUnmount } from "vue";
import { message, Modal } from "ant-design-vue";
import dayjs from "dayjs";
import {
  CheckSquareOutlined,
  ClockCircleOutlined,
  CopyOutlined,
  DeleteOutlined,
  DownloadOutlined,
  PictureOutlined,
  ReloadOutlined,
} from "@ant-design/icons-vue";
import { useRouter } from "vue-router";
import { getGenerationModels } from "@/api/config";
import { fetchHistory } from "@/api/history";
import { deleteImage, getDisplayImageUrl, getDownloadUrl, getPreviewImageUrl, resolveImageUrl } from "@/api/images";
import { deletePromptHistory } from "@/api/auth";
import type { GenerationModelOption, ImageResult, UserHistoryCard } from "@/types";

const router = useRouter();
const items = ref<UserHistoryCard[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const loading = ref(false);
const typeFilter = ref<"generate" | "inpaint" | "promptReverse" | undefined>(undefined);
const modelFilter = ref<string | undefined>(undefined);
const statusFilter = ref<"pending" | "processing" | "success" | "failed" | undefined>(undefined);
const promptFilter = ref("");
const dateRangeFilter = ref<[dayjs.Dayjs, dayjs.Dayjs] | null>(null);
const generationModels = ref<GenerationModelOption[]>([]);
const detailOpen = ref(false);
const detailItem = ref<UserHistoryCard | null>(null);
const selectedImageIds = ref<number[]>([]);
const batchMode = ref(false);
const HISTORY_POLL_INTERVAL_MS = 10000;
let historyPollTimer: ReturnType<typeof setInterval> | null = null;

const previewVisible = ref(false);
const previewSrc = ref("");

const modelOptions = computed(() => {
  const options = generationModels.value.map((item) => ({
    label: item.model_label,
    value: item.model_key,
  }));
  options.push({ label: "局部重绘", value: "inpaint" });
  options.push({ label: "提示词反推", value: "提示词反推" });
  return options;
});

const activeFilterCount = computed(() => {
  let count = 0;
  if (typeFilter.value) count += 1;
  if (modelFilter.value) count += 1;
  if (statusFilter.value) count += 1;
  if (promptFilter.value.trim()) count += 1;
  if (dateRangeFilter.value) count += 1;
  return count;
});

const currentPageIds = computed(() => items.value.map((item) => item.image_id));
const selectedItems = computed(() => (
  items.value.filter((item) => selectedImageIds.value.includes(item.image_id))
));
const selectedCount = computed(() => selectedItems.value.length);
const selectableCount = computed(() => items.value.length);
const downloadableSelectedItems = computed(() => selectedItems.value.filter((item) => !!item.image_url));
const allVisibleSelected = computed(() => (
  !!items.value.length && items.value.every((item) => selectedImageIds.value.includes(item.image_id))
));

function hasRunningTasks(list: UserHistoryCard[]) {
  return list.some((item) => item.status === "pending" || item.status === "processing");
}

function stopHistoryPolling() {
  if (historyPollTimer) {
    clearInterval(historyPollTimer);
    historyPollTimer = null;
  }
}

function syncHistoryPolling() {
  if (!hasRunningTasks(items.value)) {
    stopHistoryPolling();
    return;
  }
  if (historyPollTimer) return;
  historyPollTimer = window.setInterval(() => {
    if (loading.value) return;
    loadHistory(true);
  }, HISTORY_POLL_INTERVAL_MS);
}

async function loadHistory(silent = false) {
  loading.value = true;
  try {
    const res = await fetchHistory(page.value, pageSize.value, {
      mode: typeFilter.value,
      model: modelFilter.value,
      prompt: promptFilter.value,
      status: statusFilter.value,
      start_date: dateRangeFilter.value?.[0].startOf("day").toISOString(),
      end_date: dateRangeFilter.value?.[1].endOf("day").toISOString(),
    });
    items.value = res.items;
    total.value = res.total;
    selectedImageIds.value = selectedImageIds.value.filter((id) => res.items.some((item) => item.image_id === id));
    if (detailItem.value) {
      const refreshedDetail = res.items.find((item) => item.image_id === detailItem.value?.image_id);
      if (refreshedDetail) detailItem.value = refreshedDetail;
    }
    syncHistoryPolling();
  } catch {
    if (!silent) message.error("获取历史记录失败");
  } finally {
    loading.value = false;
  }
}

async function loadModels() {
  try {
    generationModels.value = await getGenerationModels();
  } catch {
    generationModels.value = [];
  }
}

onMounted(loadHistory);
onMounted(loadModels);
onBeforeUnmount(stopHistoryPolling);

function handlePageChange(p: number) {
  page.value = p;
  loadHistory();
}

function modeLabel(mode: UserHistoryCard["mode"]) {
  if (mode === "inpaint") return "局部重绘";
  if (mode === "promptReverse") return "提示词反推";
  return "生图";
}

function statusLabel(status: UserHistoryCard["status"]) {
  const mapping: Record<string, string> = {
    pending: "等待中",
    processing: "处理中",
    success: "成功",
    failed: "失败",
  };
  return mapping[status] || status;
}

function formatTime(t: string) {
  return t ? dayjs(t).format("YYYY-MM-DD HH:mm:ss") : "-";
}

function getModelLabel(model?: string) {
  if (!model) return "-";
  return generationModels.value.find((item) => item.model_key === model)?.model_label || model;
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
    `类型：${modeLabel(item.mode)}`,
    `模型：${getModelLabel(item.model)}`,
    `比例：${item.size || "-"}`,
    item.resolution ? `分辨率：${item.resolution}` : "",
    item.image_format ? `格式：${item.image_format}` : "",
    item.image_size_bytes ? `大小：${formatImageSize(item.image_size_bytes)}` : "",
    `时间：${formatTime(item.created_at)}`,
  ].filter(Boolean);
}

function applyFilters() {
  page.value = 1;
  loadHistory();
}

function resetFilters() {
  typeFilter.value = undefined;
  modelFilter.value = undefined;
  statusFilter.value = undefined;
  promptFilter.value = "";
  dateRangeFilter.value = null;
  page.value = 1;
  loadHistory();
}

function openPreview(url: string) {
  if (!url) return;
  previewSrc.value = url;
  previewVisible.value = true;
}

function getHistoryImageSrc(image: Pick<UserHistoryCard, "thumb_url" | "image_url" | "preview_url" | "status">) {
  const displayUrl = getDisplayImageUrl(image);
  if (displayUrl) return displayUrl;
  return image.status === "failed" ? "/failed-result.svg" : "";
}

function getHistoryCardMedia(item: UserHistoryCard) {
  if (item.mode === "promptReverse") {
    return resolveImageUrl(item.source_image_thumb || item.source_image);
  }
  return getHistoryImageSrc(item);
}

function getHistoryCardPreview(item: UserHistoryCard) {
  if (item.mode === "promptReverse") {
    return resolveImageUrl(item.source_image);
  }
  return getHistoryPreviewSrc(item);
}

function getHistoryPreviewSrc(image: Pick<UserHistoryCard, "thumb_url" | "image_url" | "preview_url">) {
  return getPreviewImageUrl(image);
}

function getNestedImageSrc(image: Pick<ImageResult, "thumb_url" | "image_url" | "preview_url" | "status">) {
  return getHistoryImageSrc(image);
}

function getNestedPreviewSrc(image: Pick<ImageResult, "thumb_url" | "image_url" | "preview_url">) {
  return getPreviewImageUrl(image);
}

function openDetail(item: UserHistoryCard) {
  detailItem.value = item;
  detailOpen.value = true;
}

function isSelected(imageId: number) {
  return selectedImageIds.value.includes(imageId);
}

function toggleSelect(imageId: number, checked: boolean) {
  if (checked) {
    if (!selectedImageIds.value.includes(imageId)) selectedImageIds.value = [...selectedImageIds.value, imageId];
    return;
  }
  selectedImageIds.value = selectedImageIds.value.filter((id) => id !== imageId);
}

function handleSelectChange(imageId: number, event: { target: { checked: boolean } }) {
  toggleSelect(imageId, event.target.checked);
}

function selectAllVisible() {
  selectedImageIds.value = [...currentPageIds.value];
}

function invertVisibleSelection() {
  selectedImageIds.value = currentPageIds.value.filter((id) => !selectedImageIds.value.includes(id));
}

function clearSelection() {
  selectedImageIds.value = [];
}

function toggleBatchMode() {
  batchMode.value = !batchMode.value;
  if (!batchMode.value) clearSelection();
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

function download(imageId: number, imageUrl: string) {
  const a = document.createElement("a");
  a.href = getDownloadUrl(imageId, imageUrl);
  a.download = `banana_${imageId}.png`;
  a.click();
}

function wait(ms: number) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

function getDownloadFilename(imageId: number, imageUrl?: string) {
  const cleanPath = (imageUrl || "").split("?")[0] || "";
  const suffix = cleanPath.includes(".") ? cleanPath.slice(cleanPath.lastIndexOf(".")) : ".png";
  return `banana_${imageId}${suffix || ".png"}`;
}

async function downloadBlob(imageId: number, imageUrl: string) {
  const url = getDownloadUrl(imageId, imageUrl);
  const headers: Record<string, string> = {};
  const token = localStorage.getItem("token");
  if (token && !/^https?:\/\//.test(url)) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error("download_failed");

  const blob = await response.blob();
  const objectUrl = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = objectUrl;
  a.download = getDownloadFilename(imageId, imageUrl);
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
}

async function handleDelete(item: UserHistoryCard) {
  Modal.confirm({
    title: item.mode === "promptReverse" ? "确认删除这条反推记录？" : "确认删除这张历史结果？",
    content: item.mode === "promptReverse"
      ? "删除后将移除这条提示词反推历史记录。"
      : "仅删除当前结果图；如果这是该任务最后一张结果图，会同时清理空任务记录。",
    centered: true,
    async onOk() {
      if (item.mode === "promptReverse" && item.history_id) {
        await deletePromptHistory(item.history_id);
      } else {
        await deleteImage(item.image_id);
      }
      message.success("删除成功");
      selectedImageIds.value = selectedImageIds.value.filter((id) => id !== item.image_id);
      if (items.value.length === 1 && page.value > 1) page.value -= 1;
      if (detailItem.value?.image_id === item.image_id) detailOpen.value = false;
      await loadHistory();
    },
  });
}

async function handleBatchDownload() {
  if (!selectedCount.value) {
    message.warning("请先选择需要下载的记录");
    return;
  }
  if (!downloadableSelectedItems.value.length) {
    message.warning("选中项中没有可下载的原图");
    return;
  }

  let successCount = 0;
  for (const item of downloadableSelectedItems.value) {
    try {
      await downloadBlob(item.image_id, item.image_url);
      successCount += 1;
      await wait(180);
    } catch {
      // continue downloading remaining items
    }
  }

  if (!successCount) {
    message.error("批量下载失败，请重试");
    return;
  }
  if (successCount < downloadableSelectedItems.value.length) {
    message.warning(`已下载 ${successCount} 张，部分图片下载失败`);
    return;
  }
  message.success(`已开始下载 ${successCount} 张图片`);
}

async function deleteSelectedItems() {
  const ids = selectedImageIds.value.slice();
  const results = await Promise.allSettled(ids.map((id) => {
    const item = items.value.find((entry) => entry.image_id === id);
    if (item?.mode === "promptReverse" && item.history_id) {
      return deletePromptHistory(item.history_id);
    }
    return deleteImage(id);
  }));
  const successIds = ids.filter((_, index) => results[index].status === "fulfilled");
  const failedCount = ids.length - successIds.length;

  if (successIds.length) {
    selectedImageIds.value = selectedImageIds.value.filter((id) => !successIds.includes(id));
    if (detailItem.value && successIds.includes(detailItem.value.image_id)) detailOpen.value = false;
    if (successIds.length === items.value.length && page.value > 1) page.value -= 1;
  }

  await loadHistory();

  if (failedCount) {
    message.warning(`已删除 ${successIds.length} 项，${failedCount} 项删除失败`);
    return;
  }
  message.success(`已删除 ${successIds.length} 项`);
}

function handleBatchDelete() {
  if (!selectedCount.value) {
    message.warning("请先选择需要删除的记录");
    return;
  }
  Modal.confirm({
    title: `确认删除已选中的 ${selectedCount.value} 条历史结果？`,
    content: "已选项会按类型分别删除：结果图走图片删除，提示词反推走历史记录删除。",
    centered: true,
    async onOk() {
      await deleteSelectedItems();
    },
  });
}

function handleReedit(item: UserHistoryCard) {
  if (item.mode === "promptReverse") {
    localStorage.setItem(
      "generateDraftFromHistory",
      JSON.stringify({
        mode: "generate",
        prompt: item.prompt,
      })
    );
  } else if (item.mode === "inpaint") {
    localStorage.setItem(
      "generateDraftFromHistory",
      JSON.stringify({
        mode: "inpaint",
        prompt: item.prompt,
        size: item.size,
        resolution: item.resolution,
        source_image: item.source_image,
      })
    );
  } else {
    localStorage.setItem(
      "generateDraftFromHistory",
      JSON.stringify({
        mode: "generate",
        model: item.model,
        prompt: item.prompt,
        reference_images: item.reference_images,
        num_images: item.num_images,
        size: item.size,
        resolution: item.resolution,
      })
    );
  }
  router.push("/generate");
}
</script>

<template>
  <div class="warm-page">
    <div class="history-topbar">
      <div class="warm-page-heading">
        <div class="warm-page-icon history-topbar-icon">
          <ClockCircleOutlined />
        </div>
        <div>
          <div class="warm-page-title history-topbar-title">历史记录</div>
          <div class="warm-page-desc">按结果图查看历史任务，详情中可查看完整参数并重新编辑。</div>
        </div>
      </div>
      <div class="history-topbar-meta">
        <span>共 {{ total }} 条结果</span>
        <span>当前第 {{ page }} 页</span>
      </div>
    </div>

    <div class="history-filter-bar">
      <a-select v-model:value="typeFilter" placeholder="全部类型" style="width: 160px" allow-clear>
        <a-select-option value="generate">生图</a-select-option>
        <a-select-option value="inpaint">局部重绘</a-select-option>
        <a-select-option value="promptReverse">提示词反推</a-select-option>
      </a-select>
      <a-select v-model:value="modelFilter" placeholder="全部模型" style="width: 170px" allow-clear>
        <a-select-option v-for="option in modelOptions" :key="option.value" :value="option.value">
          {{ option.label }}
        </a-select-option>
      </a-select>
      <a-select v-model:value="statusFilter" placeholder="全部状态" style="width: 160px" allow-clear>
        <a-select-option value="pending">等待中</a-select-option>
        <a-select-option value="processing">处理中</a-select-option>
        <a-select-option value="success">成功</a-select-option>
        <a-select-option value="failed">失败</a-select-option>
      </a-select>
      <a-input
        v-model:value="promptFilter"
        placeholder="按提示词筛选"
        style="width: min(320px, 100%)"
        allow-clear
        @pressEnter="applyFilters"
      />
      <a-range-picker
        v-model:value="dateRangeFilter"
        :placeholder="['开始日期', '结束日期']"
        style="width: 250px"
      />
      <a-button type="primary" class="history-filter-btn history-filter-btn-primary" @click="applyFilters">筛选</a-button>
      <a-button class="history-filter-btn history-filter-btn-secondary" @click="resetFilters">重置</a-button>
      <a-tooltip :title="batchMode ? '退出批量模式' : '进入批量模式'">
        <a-button
          type="text"
          class="history-filter-btn batch-mode-btn"
          :class="{ active: batchMode }"
          @click="toggleBatchMode"
        >
          <template #icon><CheckSquareOutlined /></template>
        </a-button>
      </a-tooltip>
    </div>

    <div v-if="batchMode && items.length" class="history-batch-bar warm-card">
      <div class="history-batch-summary">
        <span>已选 {{ selectedCount }} 项</span>
        <span>当前页 {{ selectableCount }} 项</span>
      </div>
      <div class="history-batch-actions">
        <a-button
          size="small"
          class="history-batch-btn history-batch-btn-secondary"
          :disabled="!items.length || allVisibleSelected"
          @click="selectAllVisible"
        >
          全选
        </a-button>
        <a-button size="small" class="history-batch-btn history-batch-btn-secondary" :disabled="!items.length" @click="invertVisibleSelection">
          反选
        </a-button>
        <a-button size="small" class="history-batch-btn history-batch-btn-secondary" :disabled="!selectedCount" @click="clearSelection">
          清空
        </a-button>
        <a-button
          size="small"
          class="history-batch-btn history-batch-btn-primary"
          :disabled="!downloadableSelectedItems.length"
          @click="handleBatchDownload"
        >
          批量下载
        </a-button>
        <a-button
          danger
          size="small"
          class="history-batch-btn history-batch-btn-danger"
          :disabled="!selectedCount"
          @click="handleBatchDelete"
        >
          批量删除
        </a-button>
      </div>
    </div>

    <a-spin :spinning="loading">
      <div v-if="!items.length && !loading" class="empty-state warm-card">
        <a-empty :description="activeFilterCount ? '没有符合条件的历史记录' : '暂无生成记录'" />
      </div>

      <div v-else class="history-grid">
        <div v-for="item in items" :key="item.image_id" class="result-card warm-card" @click="openDetail(item)">
          <div v-if="batchMode" class="result-card-select" @click.stop>
            <a-checkbox :checked="isSelected(item.image_id)" @change="handleSelectChange(item.image_id, $event)" />
          </div>

          <div class="result-card-media">
            <img
              v-if="getHistoryCardMedia(item)"
              :src="getHistoryCardMedia(item)"
              :alt="item.mode === 'promptReverse' ? '提示词反推原图' : item.status === 'failed' ? '生成失败' : '历史结果图'"
              :class="{ 'failed-result-image': item.status === 'failed' }"
              loading="lazy"
              @click.stop="getHistoryCardPreview(item) && openPreview(getHistoryCardPreview(item))"
            />
            <div v-else class="result-card-placeholder">
              <ClockCircleOutlined />
            </div>
          </div>

          <div class="result-card-body">
            <div class="result-card-mode">{{ modeLabel(item.mode) }}</div>
            <div class="result-card-file-meta">
              <span>ID：{{ item.display_id || item.image_id }}</span>
              <span>模型：{{ getModelLabel(item.model) }}</span>
              <span v-if="item.mode !== 'promptReverse'">格式：{{ item.image_format || "-" }}</span>
              <span v-if="item.mode !== 'promptReverse'">大小：{{ formatImageSize(item.image_size_bytes) }}</span>
            </div>

            <div class="result-card-actions">
              <a-tooltip title="重新编辑">
                <a-button type="text" size="small" class="ghost-icon-btn" @click.stop="handleReedit(item)">
                  <template #icon><ReloadOutlined /></template>
                </a-button>
              </a-tooltip>
              <a-tooltip title="下载">
                <a-button
                  type="text"
                  size="small"
                  class="ghost-icon-btn"
                  :disabled="!item.image_url || item.mode === 'promptReverse'"
                  @click.stop="download(item.image_id, item.image_url)"
                >
                  <template #icon><DownloadOutlined /></template>
                </a-button>
              </a-tooltip>
              <a-tooltip title="删除">
                <a-button type="text" size="small" class="ghost-icon-btn ghost-icon-btn-danger" @click.stop="handleDelete(item)">
                  <template #icon><DeleteOutlined /></template>
                </a-button>
              </a-tooltip>
            </div>
          </div>
        </div>
      </div>
    </a-spin>

    <div v-if="total > pageSize" class="warm-pagination">
      <a-pagination
        :current="page"
        :total="total"
        :page-size="pageSize"
        show-less-items
        @change="handlePageChange"
      />
    </div>

    <a-modal
      v-model:open="detailOpen"
      title="任务详情"
      :footer="null"
      :width="1040"
      centered
    >
      <template v-if="detailItem">
        <div class="detail-layout">
          <div class="detail-left">
            <div class="detail-section">
              <div class="detail-label">{{ detailItem.mode === 'promptReverse' ? '反推原图' : '该任务全部结果' }}</div>
              <div v-if="detailItem.mode === 'promptReverse' && detailItem.source_image" class="detail-thumb-row">
                <div class="detail-thumb detail-thumb-large" @click="openPreview(resolveImageUrl(detailItem.source_image))">
                  <img :src="resolveImageUrl(detailItem.source_image_thumb || detailItem.source_image)" alt="提示词反推原图" loading="lazy" />
                </div>
              </div>
              <div v-else class="detail-result-grid">
                <div
                  v-for="img in detailItem.images"
                  :key="img.id"
                  class="detail-result-card"
                  :class="{
                    single: detailItem.images.length === 1,
                    pending: !getNestedImageSrc(img) && img.status !== 'failed',
                    failed: img.status === 'failed',
                  }"
                  @click="getNestedPreviewSrc(img) && openPreview(getNestedPreviewSrc(img))"
                >
                  <img
                    v-if="getNestedImageSrc(img) || img.status === 'failed'"
                    :src="getNestedImageSrc(img) || '/failed-result.svg'"
                    :alt="img.status === 'failed' ? '生成失败' : '结果图'"
                    :class="{ 'failed-result-image': img.status === 'failed' }"
                    loading="lazy"
                  />
                  <div v-else class="result-card-placeholder">
                    等待中...
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="detail-right">
            <div class="detail-section">
              <div class="detail-label-row">
                <div class="detail-label">提示词</div>
                <a-button type="text" class="detail-copy-btn" @click="copyPrompt(detailItem.prompt)">
                  <template #icon><CopyOutlined /></template>
                  复制提示词
                </a-button>
              </div>
              <div class="detail-prompt">{{ detailItem.prompt || "-" }}</div>
            </div>

            <div v-if="detailItem.mode === 'inpaint' && detailItem.source_image" class="detail-section">
              <div class="detail-label">局部重绘原图</div>
              <div class="detail-thumb-row">
                <div class="detail-thumb" @click="openPreview(resolveImageUrl(detailItem.source_image))">
                  <img :src="resolveImageUrl(detailItem.source_image_thumb || detailItem.source_image)" alt="局部重绘原图" loading="lazy" />
                </div>
              </div>
            </div>

            <div v-if="detailItem.reference_images.length" class="detail-section">
              <div class="detail-label">
                <PictureOutlined />
                <span>参考图</span>
              </div>
              <div class="detail-thumb-row">
                <div
                  v-for="(ref, index) in detailItem.reference_images"
                  :key="index"
                  class="detail-thumb"
                  @click="openPreview(resolveImageUrl(ref))"
                >
                  <img :src="resolveImageUrl(detailItem.reference_image_thumbs[index] || ref)" alt="参考图" loading="lazy" />
                </div>
              </div>
            </div>

            <div class="detail-section">
              <div class="detail-meta">
                <span v-for="meta in detailMetaList(detailItem)" :key="meta">{{ meta }}</span>
              </div>
            </div>
          </div>
          <div class="detail-floating-actions">
            <a-tooltip title="重新编辑">
              <a-button type="text" class="ghost-icon-btn detail-action-btn" @click="handleReedit(detailItem)">
                <template #icon><ReloadOutlined /></template>
              </a-button>
            </a-tooltip>
            <a-tooltip title="下载">
              <a-button
                type="text"
                class="ghost-icon-btn detail-action-btn"
                :disabled="!detailItem.image_url"
                @click="download(detailItem.image_id, detailItem.image_url)"
              >
                <template #icon><DownloadOutlined /></template>
              </a-button>
            </a-tooltip>
          </div>
        </div>
      </template>
    </a-modal>

    <div v-if="previewVisible" style="display: none">
      <a-image
        :src="previewSrc"
        :preview="{ visible: previewVisible, onVisibleChange: (v: boolean) => (previewVisible = v) }"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.history-topbar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 8px;
}

.history-topbar-icon {
  width: 40px;
  height: 40px;
  border-radius: 14px;
  font-size: 18px;
}

.history-topbar-title {
  font-size: 20px;
}

.history-topbar-meta {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  font-size: 13px;
  color: #9b825f;
  padding-top: 6px;
}

.history-filter-bar {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  align-items: center;
  margin-bottom: 18px;
}

.history-filter-tip {
  font-size: 13px;
  color: #9b825f;
}

.history-filter-btn {
  height: 36px;
  border-radius: 12px;
  font-weight: 600;
  box-shadow: none;
}

.history-filter-btn-primary {
  border-color: #df8b1d !important;
  background: linear-gradient(135deg, #f2a533 0%, #df8b1d 100%) !important;
  color: #fff8eb !important;

  &:hover,
  &:focus {
    border-color: #c7770d !important;
    background: linear-gradient(135deg, #f5b24c 0%, #e49729 100%) !important;
    color: #ffffff !important;
  }
}

.history-filter-btn-secondary {
  border-color: #efc784 !important;
  background: #fff7e8 !important;
  color: #b16d10 !important;

  &:hover,
  &:focus {
    border-color: #e1a64a !important;
    background: #fff0d3 !important;
    color: #c7770d !important;
  }
}

.batch-mode-btn {
  width: 34px;
  border-radius: 10px;
  padding: 0 !important;
  border-color: #efc784 !important;
  background: #fff7e8 !important;
  color: #b16d10 !important;

  &:hover,
  &:focus {
    border-color: #e1a64a !important;
    color: #c7770d !important;
    background: #fff0d3 !important;
  }

  &.active {
    border-color: #df8b1d !important;
    background: linear-gradient(135deg, #f2a533 0%, #df8b1d 100%) !important;
    color: #fff8eb !important;
  }
}

.empty-state {
  padding: 80px 0;
  text-align: center;
}

.history-batch-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 18px;
  padding: 12px 14px;
}

.history-batch-summary {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  font-size: 13px;
  color: #8f7558;
}

.history-batch-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.history-batch-btn {
  min-width: 64px;
  border-radius: 10px;
  font-weight: 600;
  box-shadow: none;
}

.history-batch-btn-secondary {
  border-color: #efc784 !important;
  background: #fff7e8 !important;
  color: #b16d10 !important;

  &:hover,
  &:focus {
    border-color: #e1a64a !important;
    background: #fff0d3 !important;
    color: #c7770d !important;
  }

  &[disabled] {
    border-color: #f3dfba !important;
    background: #fffaf2 !important;
    color: #d2b489 !important;
  }
}

.history-batch-btn-primary {
  border-color: #df8b1d !important;
  background: linear-gradient(135deg, #f2a533 0%, #df8b1d 100%) !important;
  color: #fff8eb !important;

  &:hover,
  &:focus {
    border-color: #c7770d !important;
    background: linear-gradient(135deg, #f5b24c 0%, #e49729 100%) !important;
    color: #ffffff !important;
  }

  &[disabled] {
    border-color: #f0d29f !important;
    background: linear-gradient(135deg, #f7ddb1 0%, #efcb8a 100%) !important;
    color: #fff8eb !important;
  }
}

.history-batch-btn-danger {
  border-color: #efb2a9 !important;
  background: #fff4f2 !important;
  color: #c25b4e !important;

  &:hover,
  &:focus {
    border-color: #e38779 !important;
    background: #ffe8e4 !important;
    color: #d6574b !important;
  }

  &[disabled] {
    border-color: #f5d5cf !important;
    background: #fff8f6 !important;
    color: #d8aaa2 !important;
  }
}

.history-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 18px;
}

.result-card {
  position: relative;
  padding: 14px;
  cursor: pointer;
}

.result-card-select {
  position: absolute;
  top: 14px;
  left: 14px;
  z-index: 2;
  padding: 4px 6px;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.88);
  border: 1px solid rgba(241, 221, 183, 0.92);
  box-shadow: 0 6px 16px rgba(76, 52, 26, 0.08);
  backdrop-filter: blur(8px);
}

.result-card-media {
  width: 100%;
  aspect-ratio: 1 / 1;
  border-radius: 18px;
  overflow: hidden;
  background: #fff8ee;
  border: 1px solid #f1ddb7;
  cursor: pointer;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
    transition: transform 0.2s;
  }

  &:hover img {
    transform: scale(1.03);
  }
}

.result-card-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  color: #9b825f;
  text-align: center;
  font-size: 28px;
  background: #fff8ee;
}

.failed-result-image {
  object-fit: contain !important;
  padding: 14px;
  background: #fffdfb;
}

.result-card-body {
  padding-top: 12px;
}

.result-card-mode {
  font-size: 13px;
  font-weight: 700;
  color: #7b5c2d;
}

.result-card-file-meta {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-top: 10px;
  font-size: 12px;
  color: #9b825f;
}

.result-card-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 12px;
}

.ghost-icon-btn {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  color: #8f7558 !important;

  &:hover,
  &:focus {
    color: #c7800c !important;
    background: #fff4df !important;
  }
}

.ghost-icon-btn-danger {
  color: #b97d72 !important;

  &:hover,
  &:focus {
    color: #d6574b !important;
    background: #fff1ef !important;
  }
}

.detail-section + .detail-section {
  margin-top: 18px;
}

.detail-layout {
  position: relative;
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) minmax(320px, 0.8fr);
  gap: 20px;
  align-items: start;
  padding-bottom: 0;
}

.detail-left,
.detail-right {
  min-width: 0;
}

.detail-right {
  display: flex;
  flex-direction: column;
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
  color: #8a6d45;
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
  color: #a9772e !important;

  &:hover {
    background: #fff4df !important;
    color: #c7800c !important;
  }
}

.detail-prompt {
  padding: 12px 14px;
  border-radius: 14px;
  background: #fff8ee;
  border: 1px solid #f2e3c6;
  color: #4c341a;
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
  width: 84px;
  height: 84px;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid #f1ddb7;
  background: #fff8ee;
  cursor: pointer;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
}

.detail-thumb-large {
  width: min(100%, 520px);
  height: auto;
  aspect-ratio: 1 / 1;
}

.detail-result-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 14px;
}

.detail-result-card {
  height: clamp(220px, 36vh, 340px);
  border-radius: 18px;
  overflow: hidden;
  border: 1px solid #f1ddb7;
  background: #fff8ee;
  cursor: pointer;

  img,
  .result-card-placeholder {
    width: 100%;
    height: 100%;
  }

  img {
    object-fit: contain;
    display: block;
    background: #fffdfb;
  }

  &.pending {
    cursor: default;
  }

  &.failed img {
    object-fit: contain;
    padding: 18px;
    background: #fffdfb;
  }

  &.single {
    height: clamp(440px, 72vh, 680px);
  }
}

.detail-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0;
  padding: 12px 14px;
  border-radius: 14px;
  background: #fffaf2;
  border: 1px solid #f2e3c6;
  color: #8f7558;
  font-size: 13px;
  line-height: 1.8;

  span:not(:last-child)::after {
    content: "｜";
    margin: 0 8px;
    color: #d3b487;
  }
}

@media (max-width: 900px) {
  .history-topbar {
    flex-direction: column;
    align-items: stretch;
  }

  .history-batch-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .history-batch-actions {
    justify-content: flex-start;
  }

  .history-grid {
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  }

  .detail-layout {
    grid-template-columns: 1fr;
  }

  .detail-floating-actions {
    position: static;
    justify-content: flex-end;
    margin-top: 14px;
    padding: 0;
  }

  .detail-result-grid {
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  }
}
</style>
