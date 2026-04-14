<script setup lang="ts">
import { computed, ref, onMounted } from "vue";
import { message, Modal } from "ant-design-vue";
import dayjs from "dayjs";
import {
  ClockCircleOutlined,
  DeleteOutlined,
  DownloadOutlined,
  EditOutlined,
  PictureOutlined,
} from "@ant-design/icons-vue";
import { useRouter } from "vue-router";
import { getGenerationModels } from "@/api/config";
import { fetchHistory } from "@/api/history";
import { deleteImage, getDownloadUrl } from "@/api/images";
import type { GenerationModelOption, UserHistoryCard } from "@/types";

const router = useRouter();
const items = ref<UserHistoryCard[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const loading = ref(false);
const typeFilter = ref<"generate" | "inpaint" | undefined>(undefined);
const modelFilter = ref<string | undefined>(undefined);
const statusFilter = ref<"pending" | "processing" | "success" | "failed" | undefined>(undefined);
const promptFilter = ref("");
const dateRangeFilter = ref<[dayjs.Dayjs, dayjs.Dayjs] | null>(null);
const generationModels = ref<GenerationModelOption[]>([]);
const detailOpen = ref(false);
const detailItem = ref<UserHistoryCard | null>(null);

const previewVisible = ref(false);
const previewSrc = ref("");

const modelOptions = computed(() => {
  const options = generationModels.value.map((item) => ({
    label: item.model_label,
    value: item.model_key,
  }));
  options.push({ label: "局部重绘", value: "inpaint" });
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

async function loadHistory() {
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
  } catch {
    message.error("获取历史记录失败");
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

function handlePageChange(p: number) {
  page.value = p;
  loadHistory();
}

function modeLabel(mode: UserHistoryCard["mode"]) {
  return mode === "inpaint" ? "局部重绘" : "生图";
}

function modeColor(mode: UserHistoryCard["mode"]) {
  return mode === "inpaint" ? "purple" : "gold";
}

function statusColor(status: UserHistoryCard["status"]) {
  if (status === "success") return "green";
  if (status === "failed") return "red";
  if (status === "processing") return "orange";
  return "default";
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

function formatImageSize(size?: number) {
  const bytes = Number(size || 0);
  if (!bytes) return "-";
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
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

function getHistoryImageSrc(image: Pick<UserHistoryCard, "image_url" | "status">) {
  if (image.image_url) return image.image_url;
  return image.status === "failed" ? "/failed-result.svg" : "";
}

function openDetail(item: UserHistoryCard) {
  detailItem.value = item;
  detailOpen.value = true;
}

function download(imageId: number, imageUrl: string) {
  const a = document.createElement("a");
  a.href = getDownloadUrl(imageId, imageUrl);
  a.download = `banana_${imageId}.png`;
  a.click();
}

async function handleDelete(item: UserHistoryCard) {
  Modal.confirm({
    title: "确认删除这张历史结果？",
    content: "仅删除当前结果图；如果这是该任务最后一张结果图，会同时清理空任务记录。",
    centered: true,
    async onOk() {
      await deleteImage(item.image_id);
      message.success("删除成功");
      if (items.value.length === 1 && page.value > 1) page.value -= 1;
      if (detailItem.value?.image_id === item.image_id) detailOpen.value = false;
      await loadHistory();
    },
  });
}

function handleReedit(item: UserHistoryCard) {
  if (item.mode === "inpaint") {
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
      <a-button type="primary" @click="applyFilters">筛选</a-button>
      <a-button @click="resetFilters">重置</a-button>
      <span class="history-filter-tip">已启用 {{ activeFilterCount }} 个筛选条件</span>
    </div>

    <a-spin :spinning="loading">
      <div v-if="!items.length && !loading" class="empty-state warm-card">
        <a-empty :description="activeFilterCount ? '没有符合条件的历史记录' : '暂无生成记录'" />
      </div>

      <div v-else class="history-grid">
        <div v-for="item in items" :key="item.image_id" class="result-card warm-card" @click="openDetail(item)">
          <div class="result-card-media">
            <img
              v-if="getHistoryImageSrc(item)"
              :src="getHistoryImageSrc(item)"
              :alt="item.status === 'failed' ? '生成失败' : '历史结果图'"
              :class="{ 'failed-result-image': item.status === 'failed' }"
              @click.stop="openPreview(getHistoryImageSrc(item))"
            />
            <div v-else class="result-card-placeholder">
              {{ item.status === "failed" ? "生成失败" : item.status === "processing" ? "生成中..." : "等待中..." }}
            </div>
          </div>

          <div class="result-card-body">
            <div class="result-card-meta">
              <a-tag class="warm-tag" :color="statusColor(item.status)">{{ statusLabel(item.status) }}</a-tag>
              <a-tag class="warm-tag" :color="modeColor(item.mode)">{{ modeLabel(item.mode) }}</a-tag>
              <span class="result-card-time">{{ formatTime(item.created_at) }}</span>
            </div>

            <div class="result-card-file-meta">
              <span>格式：{{ item.image_format || "-" }}</span>
              <span>大小：{{ formatImageSize(item.image_size_bytes) }}</span>
            </div>

            <div class="result-card-actions">
              <a-tooltip title="重新编辑">
                <a-button shape="circle" size="small" @click.stop="handleReedit(item)">
                  <template #icon><EditOutlined /></template>
                </a-button>
              </a-tooltip>
              <a-tooltip title="下载">
                <a-button shape="circle" size="small" :disabled="!item.image_url" @click.stop="download(item.image_id, item.image_url)">
                  <template #icon><DownloadOutlined /></template>
                </a-button>
              </a-tooltip>
              <a-tooltip title="删除">
                <a-button shape="circle" size="small" danger @click.stop="handleDelete(item)">
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
      :width="840"
      centered
    >
      <template v-if="detailItem">
        <div class="detail-section">
          <div class="detail-label">提示词</div>
          <div class="detail-prompt">{{ detailItem.prompt || "-" }}</div>
        </div>

        <div class="detail-tags">
          <a-tag class="warm-tag" :color="modeColor(detailItem.mode)">{{ modeLabel(detailItem.mode) }}</a-tag>
          <a-tag v-if="detailItem.model" class="warm-tag">{{ detailItem.model }}</a-tag>
          <a-tag class="warm-tag">{{ detailItem.size }}</a-tag>
          <a-tag v-if="detailItem.resolution" class="warm-tag">{{ detailItem.resolution }}</a-tag>
          <a-tag class="warm-tag">{{ formatTime(detailItem.created_at) }}</a-tag>
        </div>

        <div v-if="detailItem.mode === 'inpaint' && detailItem.source_image" class="detail-section">
          <div class="detail-label">局部重绘原图</div>
          <div class="detail-thumb-row">
            <div class="detail-thumb" @click="openPreview(detailItem.source_image)">
              <img :src="detailItem.source_image" alt="局部重绘原图" />
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
              @click="openPreview(ref)"
            >
              <img :src="ref" alt="参考图" />
            </div>
          </div>
        </div>

        <div class="detail-section">
          <div class="detail-label">该任务全部结果</div>
          <div class="detail-thumb-row">
            <div
              v-for="img in detailItem.images"
              :key="img.id"
              class="detail-thumb detail-result-thumb"
              @click="img.image_url && openPreview(img.image_url)"
            >
              <img
                v-if="img.image_url || img.status === 'failed'"
                :src="img.image_url || '/failed-result.svg'"
                :alt="img.status === 'failed' ? '生成失败' : '结果图'"
                :class="{ 'failed-result-image': img.status === 'failed' }"
              />
              <div v-else class="result-card-placeholder">
                等待中...
              </div>
            </div>
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

.empty-state {
  padding: 80px 0;
  text-align: center;
}

.history-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 18px;
}

.result-card {
  padding: 14px;
  cursor: pointer;
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
  font-size: 14px;
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

.result-card-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.result-card-time {
  font-size: 12px;
  color: #9b825f;
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

.detail-section + .detail-section {
  margin-top: 18px;
}

.detail-label {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 10px;
  font-size: 13px;
  font-weight: 700;
  color: #8a6d45;
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

.detail-tags {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
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

.detail-result-thumb {
  width: 96px;
  height: 96px;
}

@media (max-width: 900px) {
  .history-topbar {
    flex-direction: column;
    align-items: stretch;
  }

  .history-grid {
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  }
}
</style>
