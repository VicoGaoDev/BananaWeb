<script setup lang="ts">
import { ref, onMounted } from "vue";
import { message } from "ant-design-vue";
import { DownloadOutlined, ClockCircleOutlined } from "@ant-design/icons-vue";
import { fetchHistory } from "@/api/history";
import { getDownloadUrl } from "@/api/images";
import type { HistoryItem } from "@/types";

const items = ref<HistoryItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const loading = ref(false);

const previewVisible = ref(false);
const previewSrc = ref("");

async function loadHistory() {
  loading.value = true;
  try {
    const res = await fetchHistory(page.value, pageSize.value);
    items.value = res.items;
    total.value = res.total;
  } catch {
    message.error("获取历史记录失败");
  } finally {
    loading.value = false;
  }
}

onMounted(loadHistory);

function handlePageChange(p: number) {
  page.value = p;
  loadHistory();
}

function openPreview(url: string) {
  previewSrc.value = url;
  previewVisible.value = true;
}

function download(imageId: number) {
  const a = document.createElement("a");
  a.href = getDownloadUrl(imageId);
  a.download = `banana_${imageId}.png`;
  a.click();
}

function formatTime(t: string) {
  return t ? new Date(t).toLocaleString("zh-CN") : "-";
}

function statusColor(s: string) {
  if (s === "success") return "green";
  if (s === "failed") return "red";
  if (s === "processing") return "orange";
  return "default";
}

function statusLabel(s: string) {
  const m: Record<string, string> = { success: "成功", failed: "失败", processing: "处理中", pending: "等待中" };
  return m[s] || s;
}
</script>

<template>
  <div class="warm-page">
    <div class="warm-page-header">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <ClockCircleOutlined />
        </div>
        <div>
          <div class="warm-page-title">历史记录</div>
          <div class="warm-page-desc">查看每次风格生成任务的状态、时间与结果图。</div>
        </div>
      </div>

      <div class="history-stats warm-summary-grid">
        <div class="warm-summary-item">
          <div class="warm-summary-label">任务总数</div>
          <div class="warm-summary-value">{{ total }}</div>
          <div class="warm-summary-text">按时间倒序展示你的全部记录</div>
        </div>
        <div class="warm-summary-item">
          <div class="warm-summary-label">当前页</div>
          <div class="warm-summary-value">{{ page }}</div>
          <div class="warm-summary-text">每页 {{ pageSize }} 条任务记录</div>
        </div>
      </div>
    </div>

    <a-spin :spinning="loading">
      <div v-if="!items.length && !loading" class="empty-state warm-card">
        <a-empty description="暂无生成记录" />
      </div>

      <div v-for="item in items" :key="item.task_id" class="history-card warm-card">
        <div class="hc-header">
          <span class="hc-style">{{ item.style_name }}</span>
          <a-tag class="warm-tag" :color="statusColor(item.status)">{{ statusLabel(item.status) }}</a-tag>
          <span class="hc-meta">{{ formatTime(item.created_at) }}</span>
          <a-tag class="warm-tag" color="gold" style="margin-left: auto">{{ item.model }}</a-tag>
          <a-tag class="warm-tag">{{ item.size }}</a-tag>
        </div>
        <div class="hc-images">
          <div v-for="img in item.images" :key="img.id" class="thumb-wrap">
            <template v-if="img.status === 'success' && img.image_url">
              <img :src="img.image_url" @click="openPreview(img.image_url)" />
              <a-button
                type="primary"
                shape="circle"
                size="small"
                class="thumb-dl"
                @click="download(img.id)"
              >
                <template #icon><DownloadOutlined /></template>
              </a-button>
            </template>
            <div v-else class="thumb-ph">
              {{ img.status === "failed" ? "✗" : "..." }}
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

    <div v-if="previewVisible" style="display: none">
      <a-image
        :src="previewSrc"
        :preview="{ visible: previewVisible, onVisibleChange: (v: boolean) => (previewVisible = v) }"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.history-stats {
  width: min(520px, 100%);
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.empty-state {
  padding: 80px 0;
  text-align: center;
}

.history-card {
  padding: 22px 24px;
}

.hc-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.hc-style {
  font-size: 16px;
  font-weight: 700;
  color: #4c341a;
}

.hc-meta {
  font-size: 13px;
  color: #9b825f;
}

.hc-images {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.thumb-wrap {
  width: 110px;
  height: 110px;
  border-radius: 16px;
  overflow: hidden;
  position: relative;
  border: 1px solid #f1ddb7;
  background: #fff8eb;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    cursor: pointer;
    border-radius: 16px;
    transition: transform 0.2s;

    &:hover {
      transform: scale(1.04);
    }
  }
}

.thumb-dl {
  position: absolute;
  bottom: 8px;
  right: 8px;
  opacity: 0;
  transition: opacity 0.2s;
  border: none;
  box-shadow: 0 10px 18px rgba(0, 0, 0, 0.12);

  .thumb-wrap:hover & {
    opacity: 1;
  }
}

.thumb-ph {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #fff8ee;
  border-radius: 16px;
  border: 1px dashed #e4cfa7;
  color: #b49361;
  font-size: 16px;
}

@media (max-width: 960px) {
  .history-stats {
    grid-template-columns: 1fr;
  }
}
</style>
