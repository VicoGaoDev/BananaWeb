<script setup lang="ts">
import { ref, computed, onMounted, h } from "vue";
import { message } from "ant-design-vue";
import {
  AppstoreOutlined,
  CheckCircleFilled,
  CloudUploadOutlined,
  DeleteOutlined,
  DownloadOutlined,
  EyeOutlined,
  LoadingOutlined,
  PictureOutlined,
  ReloadOutlined,
  ThunderboltOutlined,
} from "@ant-design/icons-vue";
import StyleSelector from "@/components/StyleSelector.vue";
import { fetchStyles } from "@/api/styles";
import { createTask, getTask } from "@/api/tasks";
import { getDownloadUrl, regenerateImage } from "@/api/images";
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

const selectedStyle = computed(() => styles.value.find((s) => s.id === selectedStyleId.value) || null);
const selectedStyleName = computed(() => selectedStyle.value?.name || "");

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
  if (loading.value || pendingCount.value) return "AI 正在根据当前风格逐张生成图片";
  if (images.value.length && successCount.value === images.value.length) return "本次任务已完成，可预览、下载或重新生成";
  if (images.value.length) return "部分结果已返回，请继续查看生成状态";
  return "";
});

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
      size: size.value,
      resolution: resolution.value,
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
            <h3>参考图</h3>
          </div>
        </div>

        <div class="upload-stage" @click="triggerUpload">
          <input
            ref="fileInput"
            type="file"
            accept="image/*"
            hidden
            @change="handleFileChange"
          />

          <template v-if="referenceUrl">
            <img :src="referenceUrl" class="upload-preview" alt="参考图" />
            <div class="upload-overlay">
              <a-button
                type="text"
                shape="circle"
                class="icon-chip danger"
                @click.stop="removeReference"
              >
                <template #icon><DeleteOutlined /></template>
              </a-button>
            </div>
          </template>

          <template v-else>
            <div class="upload-empty">
              <a-spin
                v-if="uploading"
                :indicator="h(LoadingOutlined, { style: { fontSize: '30px', color: '#ff9f1a' } })"
              />
              <template v-else>
                <div class="empty-illust">
                  <CloudUploadOutlined />
                </div>
                <div class="upload-title">上传参考图</div>
                <a-button type="primary" class="upload-btn">
                  <template #icon><PictureOutlined /></template>
                  选择图片
                </a-button>
              </template>
            </div>
          </template>
        </div>

        <div class="upload-foot">
          <span>支持大小不超过 10MB</span>
          <span v-if="referenceUrl">已载入参考图</span>
        </div>
      </section>

      <section class="work-panel control-panel">
        <div class="panel-head">
          <div>
            <h3>绘图设置</h3>
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

        <div class="field-block style-block">
          <button type="button" class="style-trigger" @click="styleDrawerOpen = true">
            <div class="style-trigger-cover">
              <img
                v-if="selectedStyle?.cover_image"
                :src="selectedStyle.cover_image"
                :alt="selectedStyle.name"
              />
              <div v-else class="style-trigger-ph">
                <AppstoreOutlined />
              </div>
            </div>
            <div class="style-trigger-body">
              <span class="style-trigger-label">风格图选项</span>
              <strong>{{ selectedStyleName || "点击选择风格" }}</strong>
              <span class="style-trigger-desc">
                {{ selectedStyle?.description || "选择一个风格后开始生成结果" }}
              </span>
            </div>
            <CheckCircleFilled v-if="selectedStyleId" class="style-selected-icon" />
          </button>
        </div>

        <a-button
          type="primary"
          block
          size="large"
          :loading="loading"
          :disabled="!selectedStyleId"
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
          <div class="hero-ring" :class="{ spinning: loading || pendingCount > 0 }">
            <component
              :is="LoadingOutlined"
            />
          </div>
          <div class="hero-title">
            AI 正在生成您的图片...
          </div>
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
        <div v-else class="result-empty result-empty-loading"></div>
      </section>
    </div>

    <StyleSelector
      :styles="styles"
      v-model="selectedStyleId"
      v-model:open="styleDrawerOpen"
    />

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
  grid-template-columns: 1.05fr 1.1fr 1fr;
  gap: 24px;
  align-items: start;
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

.upload-stage {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 24px;
  min-height: 520px;
  border: 2px dashed #e8d7b7;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.9), rgba(255, 248, 232, 0.92)),
    radial-gradient(circle at top, rgba(255, 196, 83, 0.12), transparent 55%);
  overflow: hidden;
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;

  &:hover {
    transform: translateY(-2px);
    border-color: #f1bd57;
    box-shadow: inset 0 0 0 1px rgba(255, 185, 55, 0.15);
  }
}

.upload-preview,
.result-frame img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.upload-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  padding: 14px;
  background: linear-gradient(180deg, rgba(76, 52, 14, 0.18), transparent 32%);
}

.upload-empty {
  width: 100%;
  min-height: 100%;
  padding: 40px 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}

.result-empty {
  min-height: 520px;
  border-radius: 24px;
  border: 1px dashed #ead9b9;
  background: linear-gradient(180deg, rgba(255, 248, 232, 0.38), rgba(255, 253, 248, 0.82));
}

.empty-illust {
  width: 88px;
  height: 88px;
  border-radius: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(180deg, #ffd87d, #ffb83d);
  color: #5f3c09;
  font-size: 40px;
  box-shadow: 0 14px 30px rgba(255, 177, 42, 0.22);
}

.upload-title,
.empty-title {
  margin-top: 18px;
  font-size: 21px;
  font-weight: 700;
  color: #4e3820;
}

.upload-subtitle,
.empty-sub {
  max-width: 280px;
  margin-top: 8px;
  color: #8f7558;
  font-size: 14px;
  line-height: 1.7;
}

.upload-btn {
  margin-top: 20px;
  height: 44px;
  padding: 0 22px;
  border-radius: 14px;
  background: linear-gradient(180deg, #ffbb42, #ff9f1a) !important;
  border: none !important;
  box-shadow: 0 14px 24px rgba(255, 159, 26, 0.22) !important;
}

.upload-foot {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  margin-top: 14px;
  font-size: 12px;
  color: #a88962;
}

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

.style-block {
  margin-top: 22px;
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

.style-trigger {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 14px;
  position: relative;
  padding: 14px;
  border-radius: 22px;
  border: 1px solid #f0ddbb;
  background: #fff;
  box-shadow: 0 8px 18px rgba(244, 182, 84, 0.08);
  cursor: pointer;
  text-align: left;
  transition: transform 0.2s ease, border-color 0.2s ease;

  &:hover {
    transform: translateY(-2px);
    border-color: #f5b64c;
  }
}

.style-trigger-cover {
  width: 84px;
  height: 84px;
  flex-shrink: 0;
  border-radius: 18px;
  overflow: hidden;
  background: #fff5df;
}

.style-trigger-ph {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #f0a62a;
  font-size: 30px;
}

.style-trigger-body {
  display: flex;
  flex-direction: column;
  gap: 5px;
  min-width: 0;

  strong {
    color: #493219;
    font-size: 17px;
  }
}

.style-trigger-label,
.style-trigger-desc {
  color: #92775a;
  font-size: 12px;
}

.style-trigger-desc {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.style-selected-icon {
  position: absolute;
  top: 14px;
  right: 14px;
  color: #ff9f1a;
  font-size: 18px;
}

.generate-btn {
  height: 54px;
  border-radius: 18px;
  font-size: 16px;
  font-weight: 700;
  background: linear-gradient(180deg, #ffc45b, #ffab25) !important;
  border: none !important;
  box-shadow: 0 16px 28px rgba(255, 169, 37, 0.28) !important;
}

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
  display: flex;
  flex-direction: column;
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
  min-height: 220px;
  border-radius: 20px;
  overflow: hidden;
  border: 1px dashed #ead9b9;
  background: #fffaf0;

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
    background: linear-gradient(180deg, rgba(255, 247, 245, 0.4), rgba(255, 247, 245, 0.86));
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

@media (max-width: 1280px) {
  .generate-workbench {
    grid-template-columns: 1fr;
  }

  .upload-stage {
    min-height: 360px;
  }
}

@media (max-width: 768px) {
  .work-panel {
    padding: 18px;
    border-radius: 22px;
  }

  .size-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .quality-row {
    grid-template-columns: 1fr;
  }

  .upload-foot {
    flex-direction: column;
  }
}
</style>
