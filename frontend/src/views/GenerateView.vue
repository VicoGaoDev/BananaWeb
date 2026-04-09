<script setup lang="ts">
import { ref, computed, h } from "vue";
import { message } from "ant-design-vue";
import {
  CloudUploadOutlined,
  DeleteOutlined,
  DownloadOutlined,
  EyeOutlined,
  LoadingOutlined,
  PictureOutlined,
  ReloadOutlined,
  ThunderboltOutlined,
} from "@ant-design/icons-vue";
import { createTask, getTask } from "@/api/tasks";
import { getDownloadUrl, regenerateImage } from "@/api/images";
import { uploadReferenceImage } from "@/api/upload";
import { usePolling } from "@/composables/usePolling";
import { useAuthStore } from "@/stores/auth";
import type { ImageResult, TaskResult } from "@/types";

const auth = useAuthStore();

const prompt = ref("");
const numImages = ref(4);
const resolution = ref("4K");
const size = ref("3:4");
const loading = ref(false);
const images = ref<ImageResult[]>([]);
const currentTaskId = ref<number | null>(null);

const MAX_REFS = 6;
const referenceUrls = ref<string[]>([]);
const uploading = ref(false);
const fileInput = ref<HTMLInputElement | null>(null);

const previewVisible = ref(false);
const previewCurrent = ref("");

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
const successCount = computed(() => images.value.filter((img) => img.status === "success").length);
const resultSummary = computed(() => {
  if (loading.value || pendingCount.value) return "AI 正在根据提示词逐张生成图片";
  if (images.value.length && successCount.value === images.value.length) return "本次任务已完成，可预览、下载或重新生成";
  if (images.value.length) return "部分结果已返回，请继续查看生成状态";
  return "";
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

  if (referenceUrls.value.length >= MAX_REFS) {
    message.warning(`最多上传 ${MAX_REFS} 张参考图`);
    input.value = "";
    return;
  }

  if (file.size > 10 * 1024 * 1024) {
    message.warning("图片大小不能超过 10MB");
    input.value = "";
    return;
  }

  uploading.value = true;
  try {
    const res = await uploadReferenceImage(file);
    referenceUrls.value.push(res.url);
    message.success("参考图上传成功");
  } catch {
    message.error("上传失败，请重试");
  } finally {
    uploading.value = false;
    input.value = "";
  }
}

function removeReference(index: number) {
  referenceUrls.value.splice(index, 1);
}

async function handleGenerate() {
  if (!auth.isLoggedIn) {
    message.warning("请先登录");
    return;
  }
  if (!prompt.value.trim()) {
    message.warning("请输入提示词");
    return;
  }
  loading.value = true;
  images.value = [];
  try {
    const res = await createTask({
      prompt: prompt.value,
      num_images: numImages.value,
      size: size.value,
      resolution: resolution.value,
      reference_images: referenceUrls.value.length ? referenceUrls.value : undefined,
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

function handleDownload(imageId: number) {
  const a = document.createElement("a");
  a.href = getDownloadUrl(imageId);
  a.download = `banana_${imageId}.png`;
  a.click();
}
</script>

<template>
  <div class="generate-page">
    <div class="generate-workbench">
      <section class="work-panel upload-panel">
        <div class="panel-head">
          <div>
            <h3>参考图 ({{ referenceUrls.length }}/{{ MAX_REFS }})</h3>
          </div>
        </div>

        <input
          ref="fileInput"
          type="file"
          accept="image/*"
          hidden
          @change="handleFileChange"
        />

        <div class="upload-grid">
          <div v-for="(url, idx) in referenceUrls" :key="idx" class="upload-thumb">
            <img :src="url" alt="参考图" />
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
            v-if="referenceUrls.length < MAX_REFS"
            class="upload-add"
            @click="triggerUpload"
          >
            <a-spin
              v-if="uploading"
              :indicator="h(LoadingOutlined, { style: { fontSize: '24px', color: '#ff9f1a' } })"
            />
            <template v-else>
              <CloudUploadOutlined style="font-size: 28px; color: #f0a62a" />
              <span>添加图片</span>
            </template>
          </div>
        </div>

        <div class="upload-foot">
          <span>支持大小不超过 10MB，最多 {{ MAX_REFS }} 张</span>
          <span v-if="referenceUrls.length">已载入 {{ referenceUrls.length }} 张</span>
        </div>
      </section>

      <section class="work-panel control-panel">
        <div class="panel-head">
          <div>
            <h3>绘图设置</h3>
          </div>
        </div>

        <div class="field-block">
          <label>提示词</label>
          <a-textarea
            v-model:value="prompt"
            :rows="4"
            placeholder="描述你想要生成的图片内容..."
            class="prompt-input"
            :maxlength="2000"
            show-count
          />
        </div>

        <div class="field-block">
          <label>生成数量</label>
          <div class="num-grid">
            <button
              v-for="n in 8"
              :key="n"
              type="button"
              :class="['size-item', { active: numImages === n }]"
              @click="numImages = n"
            >
              {{ n }}
            </button>
          </div>
        </div>

        <div class="field-block">
          <label>图片尺寸</label>
          <div class="size-grid">
            <button
              v-for="option in sizeOptions"
              :key="option.value"
              type="button"
              :class="['size-item', { active: size === option.value }]"
              @click="size = option.value"
            >
              <span class="size-shape">{{ option.label.split('  ')[0] }}</span>
              <span class="size-value">{{ option.value }}</span>
            </button>
          </div>
        </div>

        <div class="field-block">
          <label>生成质量</label>
          <div class="quality-row">
            <a-select
              v-model:value="resolution"
              :bordered="false"
              class="flat-select quality-select"
              popup-class-name="generate-dropdown"
              :options="resolutionOptions"
            />
          </div>
        </div>

        <a-button
          type="primary"
          block
          size="large"
          :loading="loading"
          :disabled="!prompt.trim()"
          class="generate-btn"
          @click="handleGenerate"
        >
          <template #icon><ThunderboltOutlined /></template>
          {{ loading ? "AI 绘制中..." : "开始生成" }}
        </a-button>
      </section>

      <section class="work-panel result-panel">
        <div class="panel-head">
          <div>
            <h3>生成结果</h3>
          </div>
        </div>

        <div v-if="loading || pendingCount > 0" class="result-hero">
          <div class="hero-ring spinning">
            <component :is="LoadingOutlined" />
          </div>
          <div class="hero-title">AI 正在生成您的图片...</div>
          <div class="hero-subtitle">{{ resultSummary }}</div>
        </div>

        <div v-if="images.length" class="result-list">
          <div v-for="(img, index) in images" :key="img.id" class="result-card">
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
                pending: img.status === 'pending',
                failed: img.status === 'failed',
                clickable: !!img.image_url,
              }"
              @click="img.image_url && handlePreview(img.image_url)"
            >
              <template v-if="img.status === 'success' && img.image_url">
                <img :src="img.image_url" alt="生成结果" />
                <div class="result-actions">
                  <a-button shape="circle" class="icon-chip" @click.stop="handlePreview(img.image_url)">
                    <template #icon><EyeOutlined /></template>
                  </a-button>
                  <a-button shape="circle" class="icon-chip" @click.stop="handleDownload(img.id)">
                    <template #icon><DownloadOutlined /></template>
                  </a-button>
                </div>
              </template>

              <template v-else-if="img.status === 'failed' && img.image_url">
                <img :src="img.image_url" alt="生成失败" class="failed-image" />
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

        <div v-else-if="!loading && pendingCount === 0" class="result-empty"></div>
      </section>
    </div>

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
}

.generate-workbench {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  align-items: start;
}

.result-panel {
  grid-column: 1 / -1;
}

.work-panel {
  background: linear-gradient(180deg, #fffaf0 0%, #fffefb 100%);
  border: 1px solid rgba(250, 186, 90, 0.24);
  border-radius: 28px;
  box-shadow: 0 18px 45px rgba(246, 178, 70, 0.12);
  padding: 22px;
}

.panel-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 18px;

  h3 {
    font-size: 20px;
    line-height: 1.2;
    color: #48321a;
  }
}

/* --- Upload grid --- */
.upload-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
}

.upload-thumb {
  position: relative;
  aspect-ratio: 1;
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid #f0ddbb;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
}

.thumb-remove {
  position: absolute;
  top: 6px;
  right: 6px;
}

.upload-add {
  aspect-ratio: 1;
  border-radius: 16px;
  border: 2px dashed #e8d7b7;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  cursor: pointer;
  color: #8f7558;
  font-size: 13px;
  background: linear-gradient(
    180deg,
    rgba(255, 255, 255, 0.9),
    rgba(255, 248, 232, 0.92)
  );
  transition: border-color 0.2s, transform 0.2s;

  &:hover {
    border-color: #f1bd57;
    transform: translateY(-2px);
  }
}

.upload-foot {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  margin-top: 14px;
  font-size: 12px;
  color: #a88962;
}

/* --- Prompt --- */
.prompt-input {
  border-radius: 16px !important;
  border-color: #efdcb9 !important;
  background: #fffdf8 !important;
  padding: 12px 16px;
  font-size: 14px;
  resize: none;

  &:focus,
  &:hover {
    border-color: #f0b85a !important;
    box-shadow: 0 0 0 3px rgba(255, 184, 90, 0.12);
  }
}

/* --- Number grid --- */
.num-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
}

/* --- Fields --- */
.field-block + .field-block {
  margin-top: 18px;
}

.field-block label {
  display: block;
  margin-bottom: 10px;
  color: #5e4524;
  font-size: 14px;
  font-weight: 700;
}

.flat-select {
  width: 100%;
  background: #fff;
  border-radius: 16px;
  border: 1px solid #f0ddbb;
  box-shadow: 0 8px 18px rgba(244, 182, 84, 0.08);

  :deep(.ant-select-selector) {
    height: 48px !important;
    padding: 0 16px !important;
    border: none !important;
    box-shadow: none !important;
    background: transparent !important;
    border-radius: 16px !important;
    font-weight: 600;
    color: #4b3318;
  }

  :deep(.ant-select-selection-item) {
    line-height: 48px !important;
  }
}

.quality-row {
  display: grid;
  grid-template-columns: 1fr;
  gap: 12px;
}

.quality-select {
  min-width: 0;
}

.size-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
}

.size-item {
  appearance: none;
  border: 1px solid #f1dfbf;
  background: #fff;
  border-radius: 18px;
  padding: 14px 8px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  color: #7a6447;
  cursor: pointer;
  transition: all 0.2s ease;
  font-weight: 700;
  font-size: 15px;

  &:hover {
    border-color: #f5b64c;
    transform: translateY(-1px);
  }

  &.active {
    background: linear-gradient(180deg, #ffb536, #ff9a16);
    border-color: #ffad2f;
    color: #fff;
    box-shadow: 0 12px 24px rgba(255, 168, 35, 0.28);
  }
}

.size-shape {
  font-size: 16px;
  line-height: 1;
}

.size-value {
  font-size: 12px;
  font-weight: 700;
}

.generate-btn {
  margin-top: 22px;
  height: 54px;
  border-radius: 18px;
  font-size: 16px;
  font-weight: 700;
  background: linear-gradient(180deg, #ffc45b, #ffab25) !important;
  border: none !important;
  box-shadow: 0 16px 28px rgba(255, 169, 37, 0.28) !important;
}

/* --- Results --- */
.result-hero {
  padding: 26px 20px;
  border-radius: 24px;
  background: linear-gradient(180deg, #fff8e8, #fffdf8);
  border: 1px solid #f1dfbe;
  text-align: center;
}

.hero-ring {
  width: 64px;
  height: 64px;
  margin: 0 auto 16px;
  border-radius: 50%;
  border: 4px solid #f6ddab;
  color: #f4a01d;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;

  &.spinning {
    animation: spin 1.1s linear infinite;
  }
}

.hero-title {
  font-size: 22px;
  font-weight: 700;
  color: #4e3820;
}

.hero-subtitle {
  margin-top: 8px;
  color: #8f7558;
  font-size: 14px;
  line-height: 1.7;
}

.result-list {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin-top: 18px;
}

.result-card {
  padding: 16px;
  border-radius: 22px;
  border: 1px solid #f1dfbe;
  background: rgba(255, 255, 255, 0.78);
}

.result-card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 12px;
  color: #594223;
  font-size: 13px;
  font-weight: 700;
}

.result-frame {
  position: relative;
  min-height: 180px;
  border-radius: 20px;
  overflow: hidden;
  border: 1px dashed #ead9b9;
  background: #fffaf0;

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
  opacity: 0.9;
}

.result-actions {
  position: absolute;
  inset: auto 14px 14px auto;
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
  margin-top: 12px;
  height: 42px;
  border-radius: 14px;
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
  width: 38px;
  height: 38px;
  border: none !important;
  background: rgba(255, 255, 255, 0.92) !important;
  color: #684825 !important;
  box-shadow: 0 10px 16px rgba(0, 0, 0, 0.1);

  &.danger {
    color: #d6574b !important;
  }
}

.result-empty {
  min-height: 220px;
  border-radius: 24px;
  border: 1px dashed #ead9b9;
  background: linear-gradient(
    180deg,
    rgba(255, 248, 232, 0.38),
    rgba(255, 253, 248, 0.82)
  );
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

  .result-list {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 640px) {
  .work-panel {
    padding: 18px;
    border-radius: 22px;
  }

  .size-grid,
  .num-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .upload-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .result-list {
    grid-template-columns: 1fr;
  }
}
</style>
