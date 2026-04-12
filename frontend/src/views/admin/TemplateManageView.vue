<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import { message, Modal } from "ant-design-vue";
import {
  DeleteOutlined,
  EditOutlined,
  PictureOutlined,
  PlusOutlined,
  UploadOutlined,
} from "@ant-design/icons-vue";
import { uploadReferenceImage } from "@/api/upload";
import { getGenerationModels } from "@/api/config";
import {
  createTemplate,
  deleteTemplate,
  getTemplateDetail,
  listAdminTemplates,
  listTemplateTags,
  updateTemplate,
  type TemplatePayload,
} from "@/api/templates";
import type { CreativeTemplate, GenerationModelOption, TemplateTag } from "@/types";

const templates = ref<CreativeTemplate[]>([]);
const tags = ref<TemplateTag[]>([]);
const modelOptions = ref<GenerationModelOption[]>([]);
const loading = ref(false);
const modalOpen = ref(false);
const saving = ref(false);
const editingId = ref<number | null>(null);

const refInput = ref<HTMLInputElement | null>(null);
const resultInput = ref<HTMLInputElement | null>(null);
const refUploading = ref(false);
const resultUploading = ref(false);

const form = reactive<TemplatePayload>({
  prompt: "",
  model: "banana_pro",
  reference_images: [],
  num_images: 1,
  size: "9:16",
  resolution: "2K",
  result_image: "",
  tag_names: [],
});

const columns = [
  { title: "结果图", dataIndex: "result_image", width: 110 },
  { title: "提示词", dataIndex: "prompt", ellipsis: true },
  { title: "标签", key: "tags", width: 220 },
  { title: "参数", key: "meta", width: 180 },
  { title: "创建时间", dataIndex: "created_at", width: 180 },
  { title: "操作", key: "action", width: 160 },
];

const sizeOptions = [
  { label: "1:1", value: "1:1" },
  { label: "2:3", value: "2:3" },
  { label: "3:2", value: "3:2" },
  { label: "3:4", value: "3:4" },
  { label: "4:3", value: "4:3" },
  { label: "9:16", value: "9:16" },
  { label: "16:9", value: "16:9" },
];

const resolutionOptions = [
  { label: "1K", value: "1K" },
  { label: "2K", value: "2K" },
  { label: "4K", value: "4K" },
];

const tagOptions = computed(() => tags.value.map((tag) => ({ label: tag.name, value: tag.name })));
const selectedModelOption = computed(() => modelOptions.value.find((item) => item.model_key === form.model) || null);
const hideResolution = computed(() => !!selectedModelOption.value?.hide_resolution);

function resetForm() {
  editingId.value = null;
  form.prompt = "";
  form.model = modelOptions.value[0]?.model_key || "banana_pro";
  form.reference_images = [];
  form.num_images = 1;
  form.size = "9:16";
  form.resolution = "2K";
  form.result_image = "";
  form.tag_names = [];
}

async function load() {
  loading.value = true;
  try {
    templates.value = await listAdminTemplates();
  } catch {
    message.error("获取模版列表失败");
  } finally {
    loading.value = false;
  }
}

async function loadTags() {
  try {
    tags.value = await listTemplateTags();
  } catch {
    // ignore
  }
}

async function loadModels() {
  try {
    modelOptions.value = await getGenerationModels();
    if (!modelOptions.value.some((item) => item.model_key === form.model) && modelOptions.value.length) {
      form.model = modelOptions.value[0].model_key;
    }
  } catch {
    // ignore
  }
}

onMounted(() => {
  load();
  loadTags();
  loadModels();
});

function openCreate() {
  resetForm();
  modalOpen.value = true;
}

async function openEdit(item: CreativeTemplate) {
  try {
    const detail = await getTemplateDetail(item.id);
    editingId.value = item.id;
    form.prompt = detail.prompt;
    form.model = detail.model || modelOptions.value[0]?.model_key || "banana_pro";
    form.reference_images = [...detail.reference_images];
    form.num_images = 1;
    form.size = detail.size;
    form.resolution = detail.resolution;
    form.result_image = detail.result_image;
    form.tag_names = detail.tags.map((tag) => tag.name);
    modalOpen.value = true;
  } catch {
    message.error("获取模版详情失败");
  }
}

async function handleSave() {
  if (!form.prompt.trim()) {
    message.warning("请输入提示词");
    return;
  }
  if (!form.result_image) {
    message.warning("请上传结果图");
    return;
  }
  saving.value = true;
  try {
    const payload: TemplatePayload = {
      prompt: form.prompt.trim(),
      model: form.model,
      reference_images: [...form.reference_images],
      num_images: 1,
      size: form.size,
      resolution: hideResolution.value ? "" : form.resolution,
      result_image: form.result_image,
      tag_names: [...form.tag_names],
    };
    if (editingId.value) await updateTemplate(editingId.value, payload);
    else await createTemplate(payload);
    message.success(editingId.value ? "模版更新成功" : "模版创建成功");
    modalOpen.value = false;
    resetForm();
    load();
    loadTags();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "保存失败");
  } finally {
    saving.value = false;
  }
}

function handleDelete(item: CreativeTemplate) {
  Modal.confirm({
    title: "确认删除该模版？",
    centered: true,
    async onOk() {
      await deleteTemplate(item.id);
      message.success("删除成功");
      load();
      loadTags();
    },
  });
}

function triggerRefUpload() {
  refInput.value?.click();
}

function triggerResultUpload() {
  resultInput.value?.click();
}

async function handleRefUpload(e: Event) {
  const input = e.target as HTMLInputElement;
  const files = Array.from(input.files || []);
  if (!files.length) return;
  refUploading.value = true;
  try {
    for (const file of files) {
      const res = await uploadReferenceImage(file);
      form.reference_images.push(res.url);
    }
    message.success("参考图上传成功");
  } catch {
    message.error("参考图上传失败");
  } finally {
    refUploading.value = false;
    input.value = "";
  }
}

async function handleResultUpload(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  resultUploading.value = true;
  try {
    const res = await uploadReferenceImage(file);
    form.result_image = res.url;
    message.success("结果图上传成功");
  } catch {
    message.error("结果图上传失败");
  } finally {
    resultUploading.value = false;
    input.value = "";
  }
}

function removeRef(index: number) {
  form.reference_images.splice(index, 1);
}

function fmtTime(t: string) {
  return t ? new Date(t).toLocaleString("zh-CN") : "-";
}
</script>

<template>
  <div class="warm-page">
    <div class="warm-page-header">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <PictureOutlined />
        </div>
        <div>
          <div class="warm-page-title">模版管理</div>
          <div class="warm-page-desc">维护创意模版内容、标签和展示结果图。</div>
        </div>
      </div>
      <a-button type="primary" class="warm-primary-btn" @click="openCreate">
        <template #icon><PlusOutlined /></template>
        新增模版
      </a-button>
    </div>

    <div class="warm-card warm-table-card">
      <a-table
        :columns="columns"
        :data-source="templates"
        :loading="loading"
        row-key="id"
        :pagination="false"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.dataIndex === 'result_image'">
            <div class="thumb-box">
              <img v-if="record.result_image" :src="record.result_image" alt="结果图" />
            </div>
          </template>
          <template v-else-if="column.key === 'tags'">
            <div class="tag-list">
              <a-tag v-for="tag in record.tags" :key="tag.id" class="warm-tag">{{ tag.name }}</a-tag>
            </div>
          </template>
          <template v-else-if="column.key === 'meta'">
            <div class="meta-cell">
              {{ record.model || "-" }} / {{ record.size }}<span v-if="record.resolution"> / {{ record.resolution }}</span>
            </div>
          </template>
          <template v-else-if="column.dataIndex === 'created_at'">
            {{ fmtTime(record.created_at) }}
          </template>
          <template v-else-if="column.key === 'action'">
            <a-button type="link" size="small" @click="openEdit(record)">
              <template #icon><EditOutlined /></template>
              编辑
            </a-button>
            <a-divider type="vertical" />
            <a-button type="link" danger size="small" @click="handleDelete(record)">
              <template #icon><DeleteOutlined /></template>
              删除
            </a-button>
          </template>
        </template>
      </a-table>
    </div>

    <a-modal
      v-model:open="modalOpen"
      :title="editingId ? '编辑模版' : '新增模版'"
      :confirm-loading="saving"
      ok-text="保存"
      cancel-text="取消"
      centered
      :width="760"
      @ok="handleSave"
      @cancel="resetForm"
    >
      <a-form layout="vertical" style="margin-top: 16px">
        <a-form-item label="提示词">
          <a-textarea v-model:value="form.prompt" :rows="5" :maxlength="2000" show-count />
        </a-form-item>

        <div class="form-grid">
          <a-form-item label="模型">
            <a-select v-model:value="form.model" placeholder="请选择模型">
              <a-select-option v-for="model in modelOptions" :key="model.model_key" :value="model.model_key">
                {{ model.model_label }}
              </a-select-option>
            </a-select>
          </a-form-item>
          <a-form-item label="宽高比">
            <a-select v-model:value="form.size" :options="sizeOptions" />
          </a-form-item>
          <a-form-item v-if="!hideResolution" label="分辨率">
            <a-select v-model:value="form.resolution" :options="resolutionOptions" />
          </a-form-item>
          <a-form-item label="所属标签">
            <a-select
              v-model:value="form.tag_names"
              mode="tags"
              :options="tagOptions"
              placeholder="输入或选择标签"
            />
          </a-form-item>
        </div>

        <a-form-item label="结果图">
          <div class="result-upload">
            <div class="result-preview">
              <img v-if="form.result_image" :src="form.result_image" alt="结果图" />
              <div v-else class="result-placeholder">请上传结果图</div>
            </div>
            <input ref="resultInput" type="file" accept="image/*" hidden @change="handleResultUpload" />
            <a-button :loading="resultUploading" @click="triggerResultUpload">
              <template #icon><UploadOutlined /></template>
              上传结果图
            </a-button>
          </div>
        </a-form-item>

        <a-form-item label="参考图片（可选）" style="margin-bottom: 0">
          <input ref="refInput" type="file" accept="image/*" multiple hidden @change="handleRefUpload" />
          <div class="ref-grid">
            <div v-for="(url, idx) in form.reference_images" :key="url + idx" class="ref-item">
              <img :src="url" alt="参考图" />
              <a-button type="text" danger shape="circle" class="ref-remove" @click="removeRef(idx)">
                <template #icon><DeleteOutlined /></template>
              </a-button>
            </div>
            <a-button class="ref-add" :loading="refUploading" @click="triggerRefUpload">
              <template #icon><UploadOutlined /></template>
              上传参考图
            </a-button>
          </div>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<style scoped lang="scss">
.thumb-box {
  width: 72px;
  height: 72px;
  border-radius: 12px;
  overflow: hidden;
  background: #fff8ec;
  border: 1px solid #f0dfbe;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.meta-cell {
  color: #6b5436;
  font-weight: 600;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 16px;
}

.result-upload {
  display: flex;
  align-items: flex-start;
  gap: 16px;
}

.result-preview {
  width: 132px;
  height: 132px;
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid #f0dfbe;
  background: #fff8ec;
  flex-shrink: 0;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
}

.result-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #a88e68;
  font-size: 13px;
}

.ref-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.ref-item {
  position: relative;
  width: 84px;
  height: 84px;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid #f0dfbe;
  background: #fff8ec;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
}

.ref-remove {
  position: absolute;
  top: 4px;
  right: 4px;
  background: rgba(255, 255, 255, 0.92) !important;
}

.ref-add {
  height: 84px;
  min-width: 120px;
  border-radius: 14px;
}

@media (max-width: 720px) {
  .form-grid {
    grid-template-columns: 1fr;
  }

  .result-upload {
    flex-direction: column;
  }
}
</style>
