<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { message, Image as AImage } from "ant-design-vue";
import {
  PictureOutlined,
  AppstoreOutlined,
  CloudUploadOutlined,
  DeleteOutlined,
} from "@ant-design/icons-vue";
import StyleSelector from "@/components/StyleSelector.vue";
import ImageCard from "@/components/ImageCard.vue";
import { fetchStyles } from "@/api/styles";
import { createTask, getTask } from "@/api/tasks";
import { regenerateImage } from "@/api/images";
import { uploadReferenceImage } from "@/api/upload";
import { usePolling } from "@/composables/usePolling";
import type { Style, ImageResult, TaskResult } from "@/types";

const styles = ref<Style[]>([]);
const selectedStyleId = ref<number | null>(null);
const model = ref("banana-pro");
const resolution = ref("4K");
const size = ref("3:4");
const loading = ref(false);
const images = ref<ImageResult[]>([]);
const currentTaskId = ref<number | null>(null);

const referenceUrl = ref("");
const uploading = ref(false);
const fileInput = ref<HTMLInputElement | null>(null);
const styleDrawerOpen = ref(false);

const previewVisible = ref(false);
const previewCurrent = ref("");

const selectedStyleName = computed(() => {
  const s = styles.value.find((s) => s.id === selectedStyleId.value);
  return s ? s.name : "";
});

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

const baseSizes: Record<string, Record<string, string>> = {
  "1K": {
    "1:1": "1024x1024",
    "2:3": "682x1024",
    "3:2": "1024x682",
    "3:4": "768x1024",
    "4:3": "1024x768",
    "9:16": "576x1024",
    "16:9": "1024x576",
  },
  "2K": {
    "1:1": "2048x2048",
    "2:3": "1366x2048",
    "3:2": "2048x1366",
    "3:4": "1536x2048",
    "4:3": "2048x1536",
    "9:16": "1152x2048",
    "16:9": "2048x1152",
  },
  "4K": {
    "1:1": "4096x4096",
    "2:3": "2732x4096",
    "3:2": "4096x2732",
    "3:4": "3072x4096",
    "4:3": "4096x3072",
    "9:16": "2304x4096",
    "16:9": "4096x2304",
  },
};

function getResolvedSize(): string {
  return baseSizes[resolution.value]?.[size.value] || "4096x4096";
}

onMounted(async () => {
  try {
    styles.value = await fetchStyles();
  } catch {
    message.error("获取风格列表失败");
  }
});

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

function triggerUpload() {
  fileInput.value?.click();
}

async function handleFileChange(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;

  if (file.size > 10 * 1024 * 1024) {
    message.warning("图片大小不能超过 10MB");
    return;
  }

  uploading.value = true;
  try {
    const res = await uploadReferenceImage(file);
    referenceUrl.value = res.url;
    message.success("参考图上传成功");
  } catch {
    message.error("上传失败，请重试");
  } finally {
    uploading.value = false;
    input.value = "";
  }
}

function removeReference() {
  referenceUrl.value = "";
}

async function handleGenerate() {
  if (!selectedStyleId.value) {
    message.warning("请先选择风格");
    return;
  }
  loading.value = true;
  images.value = [];
  try {
    const res = await createTask({
      style_id: selectedStyleId.value,
      model: model.value,
      size: getResolvedSize(),
      reference_image: referenceUrl.value || undefined,
    });
    currentTaskId.value = res.task_id;
    const taskData = await getTask(res.task_id);
    images.value = taskData.images;
    polling.start();
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
</script>

<template>
  <div class="gen-layout">
    <!-- Left Panel -->
    <div class="gen-sidebar">
      <!-- Reference Image Upload -->
      <div class="ref-card" @click="triggerUpload">
        <input
          ref="fileInput"
          type="file"
          accept="image/*"
          hidden
          @change="handleFileChange"
        />
        <template v-if="referenceUrl">
          <img :src="referenceUrl" class="ref-img" alt="参考图" />
          <div class="ref-overlay">
            <a-button
              type="text"
              shape="circle"
              class="ref-delete"
              @click.stop="removeReference"
            >
              <template #icon><DeleteOutlined /></template>
            </a-button>
          </div>
        </template>
        <template v-else>
          <div class="ref-placeholder">
            <a-spin v-if="uploading" />
            <template v-else>
              <CloudUploadOutlined class="ref-icon" />
              <span class="ref-text">参考图</span>
              <span class="ref-hint">点击上传本地图片</span>
            </template>
          </div>
        </template>
      </div>

      <!-- Params Row -->
      <div class="param-row">
        <a-select
          v-model:value="resolution"
          :options="resolutionOptions"
          class="res-select"
          popup-class-name="ratio-dropdown"
          :bordered="false"
        >
          <template #suffixIcon><PictureOutlined /></template>
        </a-select>
        <a-select
          v-model:value="size"
          :options="sizeOptions"
          class="ratio-select"
          popup-class-name="ratio-dropdown"
          :bordered="false"
        />
      </div>

      <!-- Style Picker Button -->
      <a-button block class="style-picker-btn" @click="styleDrawerOpen = true">
        <template #icon><AppstoreOutlined /></template>
        {{ selectedStyleName ? `风格：${selectedStyleName}` : "风格图选项" }}
      </a-button>

      <!-- Generate Button -->
      <a-button
        type="primary"
        block
        size="large"
        :loading="loading"
        :disabled="!selectedStyleId"
        class="gen-btn"
        @click="handleGenerate"
      >
        {{ loading ? "生成中..." : "🎨  开始生成" }}
      </a-button>
    </div>

    <!-- Right Panel -->
    <div class="gen-main">
      <template v-if="images.length">
        <div class="grid-2x2">
          <ImageCard
            v-for="img in images"
            :key="img.id"
            :image="img"
            @regenerate="handleRegenerate"
            @preview="handlePreview"
          />
        </div>
      </template>
      <template v-else>
        <div class="empty-area dashboard-card">
          <PictureOutlined style="font-size: 56px; color: #d9d9d9" />
          <p class="empty-title">选择风格并点击生成</p>
          <p class="empty-sub">AI 生成结果将在这里展示</p>
        </div>
      </template>
    </div>

    <!-- Style Drawer -->
    <StyleSelector
      :styles="styles"
      v-model="selectedStyleId"
      v-model:open="styleDrawerOpen"
    />

    <!-- Preview -->
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
.gen-layout {
  display: grid;
  grid-template-columns: 280px 1fr;
  gap: 28px;
  align-items: start;
}

.gen-sidebar {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

/* Reference Image Card */
.ref-card {
  width: 100%;
  aspect-ratio: 3 / 4;
  border-radius: var(--card-radius);
  background: #fff;
  box-shadow: var(--card-shadow);
  overflow: hidden;
  cursor: pointer;
  position: relative;
  transition: box-shadow 0.25s;

  &:hover {
    box-shadow: 0 20px 27px rgba(0, 0, 0, 0.1);
  }
}

.ref-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.ref-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0);
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  padding: 8px;
  transition: background 0.2s;

  .ref-card:hover & {
    background: rgba(0, 0, 0, 0.25);
  }
}

.ref-delete {
  color: #fff;
  font-size: 18px;
  opacity: 0;
  transition: opacity 0.2s;

  .ref-card:hover & {
    opacity: 1;
  }
}

.ref-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.ref-icon {
  font-size: 48px;
  color: #d9d9d9;
}

.ref-text {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-secondary);
}

.ref-hint {
  font-size: 12px;
  color: var(--text-muted);
}

/* Params */
.param-row {
  display: flex;
  gap: 10px;
  align-items: center;
}

.res-select {
  width: 90px;
  flex-shrink: 0;
  background: #fff;
  border-radius: 8px;
  box-shadow: var(--card-shadow);

  :deep(.ant-select-selector) {
    height: 36px !important;
    border-radius: 8px !important;
    padding-left: 12px !important;
    font-weight: 600;
    font-size: 13px;
  }
}

.ratio-select {
  flex: 1;
  background: #fff;
  border-radius: 8px;
  box-shadow: var(--card-shadow);

  :deep(.ant-select-selector) {
    height: 36px !important;
    border-radius: 8px !important;
    padding-left: 12px !important;
    font-weight: 600;
    font-size: 13px;
  }
}

.style-picker-btn {
  height: 40px;
  border-radius: 8px;
  font-weight: 500;
  box-shadow: var(--card-shadow);
  border: none;
  background: #fff;

  &:hover {
    color: var(--primary);
    border-color: var(--primary);
  }
}

.gen-btn {
  height: 48px;
  font-size: 16px;
  font-weight: 700;
  border-radius: 10px;
  margin-top: 4px;
}

/* Right area */
.gen-main {
  min-height: 400px;
}

.grid-2x2 {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
}

.empty-area {
  min-height: 480px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 40px;
}

.empty-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-secondary);
  margin-top: 8px;
}

.empty-sub {
  font-size: 13px;
  color: var(--text-muted);
}

@media (max-width: 768px) {
  .gen-layout {
    grid-template-columns: 1fr;
  }

  .gen-sidebar {
    max-width: 300px;
    margin: 0 auto;
  }
}
</style>
