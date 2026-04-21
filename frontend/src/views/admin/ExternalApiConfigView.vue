<script setup lang="ts">
import { computed, h, onMounted, reactive, ref } from "vue";
import { message, Modal } from "ant-design-vue";
import {
  CopyOutlined,
  EditOutlined,
  EyeInvisibleOutlined,
  EyeOutlined,
  PlusOutlined,
  SaveOutlined,
} from "@ant-design/icons-vue";
import {
  createExternalApiConfig,
  getExternalApiSecrets,
  listExternalApiConfigs,
  listExternalApiSceneBindings,
  setExternalApiSecrets,
  testExternalApiConfig,
  updateExternalApiConfig,
  updateExternalApiConfigStatus,
  updateExternalApiSceneBinding,
} from "@/api/admin";
import type {
  ExternalApiConfig,
  ExternalApiConfigPayload,
  ExternalApiConfigTestResult,
  ExternalApiSceneBinding,
} from "@/types";

const configs = ref<ExternalApiConfig[]>([]);
const sceneBindings = ref<ExternalApiSceneBinding[]>([]);
const loading = ref(false);
const secretSaving = ref(false);
const saving = ref(false);
const testing = ref(false);
const bindingSavingKey = ref("");
const modalOpen = ref(false);
const editingId = ref<number | null>(null);
const isCopyMode = ref(false);
const configGroupFilter = ref("all");
const bindingGroupFilter = ref("all");
const secretVisible = ref(false);
const tongyiSecretVisible = ref(false);
const geminiKey = ref("");
const tongyiKey = ref("");

const configColumns = [
  { title: "名称", dataIndex: "name", width: 180 },
  { title: "分组", dataIndex: "group_name", width: 140 },
  { title: "请求地址", dataIndex: "request_url", ellipsis: true },
  { title: "状态", dataIndex: "status", width: 100 },
  { title: "更新时间", dataIndex: "updated_at", width: 180 },
  { title: "操作", key: "action", width: 260 },
];

const bindingColumns = [
  { title: "调用场景", key: "scene", width: 220 },
  { title: "显示文案", key: "copy", width: 320 },
  { title: "当前绑定接口", key: "current", width: 220 },
  { title: "选择接口", key: "bind", width: 360 },
  { title: "消耗积分", key: "credit", width: 180 },
];

const form = reactive<ExternalApiConfigPayload>({
  name: "",
  description: "",
  group_name: "默认",
  request_url: "",
  headers_json: '{\n  "Content-Type": "application/json"\n}',
  payload_json: "{\n\n}",
  status: "enabled",
});

const modalTitle = computed(() => {
  if (editingId.value) return "编辑接口配置";
  if (isCopyMode.value) return "复制新增接口配置";
  return "新增接口配置";
});
const groupOptions = computed(() => {
  const groups = Array.from(new Set(configs.value.map((item) => item.group_name || "未分组").filter(Boolean)));
  return groups.sort((a, b) => a.localeCompare(b, "zh-CN"));
});
const filteredConfigs = computed(() => (
  configGroupFilter.value === "all"
    ? configs.value
    : configs.value.filter((item) => item.group_name === configGroupFilter.value)
));
const maskedGeminiKey = computed(() => {
  if (!geminiKey.value) return "";
  const value = geminiKey.value;
  if (value.length <= 8) return "••••••••";
  return value.slice(0, 4) + "••••••••" + value.slice(-4);
});
const maskedTongyiKey = computed(() => {
  if (!tongyiKey.value) return "";
  const value = tongyiKey.value;
  if (value.length <= 8) return "••••••••";
  return value.slice(0, 4) + "••••••••" + value.slice(-4);
});

function resetForm() {
  editingId.value = null;
  isCopyMode.value = false;
  form.name = "";
  form.description = "";
  form.group_name = "默认";
  form.request_url = "";
  form.headers_json = '{\n  "Content-Type": "application/json"\n}';
  form.payload_json = "{\n\n}";
  form.status = "enabled";
}

function fillForm(item: ExternalApiConfig) {
  editingId.value = item.id;
  isCopyMode.value = false;
  form.name = item.name;
  form.description = item.description || "";
  form.group_name = item.group_name || "默认";
  form.request_url = item.request_url;
  form.headers_json = item.headers_json;
  form.payload_json = item.payload_json;
  form.status = item.status;
}

function buildCopiedName(sourceName: string) {
  const trimmed = sourceName.trim() || "未命名接口";
  const existingNames = new Set(configs.value.map((item) => item.name.trim()));
  const baseName = `${trimmed}（副本）`;
  if (!existingNames.has(baseName)) return baseName;

  let index = 2;
  while (existingNames.has(`${trimmed}（副本${index}）`)) {
    index += 1;
  }
  return `${trimmed}（副本${index}）`;
}

function getBindingOptions() {
  return configs.value
    .filter((item) => item.status === "enabled")
    .filter((item) => bindingGroupFilter.value === "all" || item.group_name === bindingGroupFilter.value)
    .map((item) => ({
      label: `${item.name}${item.group_name ? ` (${item.group_name})` : ""}`,
      value: item.id,
    }));
}

async function load() {
  loading.value = true;
  try {
    const [configRows, bindingRows, secretConfig] = await Promise.all([
      listExternalApiConfigs(),
      listExternalApiSceneBindings(),
      getExternalApiSecrets(),
    ]);
    configs.value = configRows;
    sceneBindings.value = bindingRows;
    geminiKey.value = secretConfig?.key || "";
    tongyiKey.value = secretConfig?.tongyi_key || "";
  } catch (err: any) {
    message.error(err.response?.data?.detail || "获取接口管理数据失败");
  } finally {
    loading.value = false;
  }
}

onMounted(load);

function openCreate() {
  resetForm();
  modalOpen.value = true;
}

function openEdit(item: ExternalApiConfig) {
  fillForm(item);
  modalOpen.value = true;
}

function openCopy(item: ExternalApiConfig) {
  resetForm();
  isCopyMode.value = true;
  form.name = buildCopiedName(item.name);
  form.description = item.description || "";
  form.group_name = item.group_name || "默认";
  form.request_url = item.request_url;
  form.headers_json = item.headers_json;
  form.payload_json = item.payload_json;
  form.status = item.status;
  modalOpen.value = true;
}

function validateJsonFields() {
  try {
    const headers = JSON.parse(form.headers_json);
    if (!headers || Array.isArray(headers) || typeof headers !== "object") {
      message.warning("Header JSON 必须是对象");
      return false;
    }
  } catch {
    message.warning("Header JSON 不是合法的 JSON");
    return false;
  }

  try {
    JSON.parse(form.payload_json);
  } catch {
    message.warning("请求 JSON 不是合法的 JSON");
    return false;
  }

  return true;
}

function buildPayload(): ExternalApiConfigPayload {
  return {
    name: form.name.trim(),
    description: form.description.trim(),
    group_name: form.group_name.trim() || "默认",
    request_url: form.request_url.trim(),
    headers_json: form.headers_json,
    payload_json: form.payload_json,
    status: form.status,
  };
}

async function handleSave() {
  if (!form.name.trim()) {
    message.warning("请输入配置名称");
    return;
  }
  if (!form.request_url.trim()) {
    message.warning("请输入请求地址");
    return;
  }
  if (!validateJsonFields()) return;

  saving.value = true;
  try {
    const payload = buildPayload();
    if (editingId.value) {
      await updateExternalApiConfig(editingId.value, payload);
      message.success("接口配置更新成功");
    } else {
      await createExternalApiConfig(payload);
      message.success("接口配置创建成功");
    }
    modalOpen.value = false;
    resetForm();
    await load();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "保存失败");
  } finally {
    saving.value = false;
  }
}

async function handleTestConnection() {
  if (!form.name.trim()) {
    message.warning("请先填写配置名称");
    return;
  }
  if (!form.request_url.trim()) {
    message.warning("请先填写请求地址");
    return;
  }
  if (!validateJsonFields()) return;

  testing.value = true;
  try {
    const result = await testExternalApiConfig(buildPayload());
    showTestResult(result);
  } catch (err: any) {
    message.error(err.response?.data?.detail || "测试连接失败");
  } finally {
    testing.value = false;
  }
}

function showTestResult(result: ExternalApiConfigTestResult) {
  Modal.info({
    title: result.success ? "测试连接成功" : "测试连接失败",
    width: 760,
    centered: true,
    okText: "知道了",
    content: [
      `请求地址：${result.request_url}`,
      `状态码：${result.status_code ?? "-"}`,
      "",
      "响应摘要：",
      result.response_preview || "(空响应)",
    ].join("\n"),
  });
}

function handleToggleStatus(item: ExternalApiConfig) {
  const nextStatus = item.status === "enabled" ? "disabled" : "enabled";
  Modal.confirm({
    title: nextStatus === "enabled" ? "启用该接口配置？" : "停用该接口配置？",
    centered: true,
    onOk: async () => {
      try {
        await updateExternalApiConfigStatus(item.id, nextStatus);
        message.success(nextStatus === "enabled" ? "已启用" : "已停用");
        await load();
      } catch (err: any) {
        message.error(err.response?.data?.detail || "更新状态失败");
      }
    },
  });
}

async function handleBindingChange(
  sceneKey: ExternalApiSceneBinding["scene_key"],
  payload: {
    api_config_id: number | null;
    credit_cost: number;
    display_name: string;
    subtitle: string;
  },
) {
  bindingSavingKey.value = sceneKey;
  try {
    await updateExternalApiSceneBinding(sceneKey, payload);
    message.success("场景绑定已更新");
    await load();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "更新绑定失败");
  } finally {
    bindingSavingKey.value = "";
  }
}

function buildBindingPayload(record: ExternalApiSceneBinding, overrides: Partial<{
  api_config_id: number | null;
  credit_cost: number;
  display_name: string;
  subtitle: string;
}> = {}) {
  return {
    api_config_id: overrides.api_config_id ?? record.api_config_id ?? null,
    credit_cost: overrides.credit_cost ?? record.credit_cost,
    display_name: overrides.display_name ?? record.display_name ?? "",
    subtitle: overrides.subtitle ?? record.subtitle ?? "",
  };
}

async function handleSaveSecrets() {
  secretSaving.value = true;
  try {
    await setExternalApiSecrets({
      key: geminiKey.value.trim(),
      tongyi_key: tongyiKey.value.trim(),
    });
    message.success("接口密钥保存成功");
    await load();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "接口密钥保存失败");
  } finally {
    secretSaving.value = false;
  }
}

function copySecret(value: string, label: string) {
  if (!value) return;
  navigator.clipboard.writeText(value).then(() => {
    message.success(`${label}已复制到剪贴板`);
  });
}
</script>

<template>
  <div class="page warm-page motion-page-enter">
    <a-space direction="vertical" :size="16" style="width: 100%">
      <a-card title="接口密钥" class="warm-card api-card motion-fade-up motion-card-lift" style="--motion-delay: 40ms" :loading="loading">
        <a-alert
          class="warm-alert"
          type="info"
          show-icon
          message="Gemini API Key 与通义千问 API Key 仅超级管理员可见，可在接口模板中通过 {{ api_key }} 和 {{ bearer_token }} 占位符使用。"
          style="margin-bottom: 16px"
        />
        <div class="secret-grid">
          <div>
            <div class="secret-label">Gemini API Key</div>
            <div class="secret-input-row">
              <a-input
                v-if="secretVisible"
                v-model:value="geminiKey"
                class="warm-input"
                placeholder="请输入 Gemini API Key"
              />
              <div v-else class="secret-masked" @click="secretVisible = true">
                {{ geminiKey ? maskedGeminiKey : "暂未配置" }}
              </div>
              <a-button class="api-secondary-btn api-icon-btn" @click="secretVisible = !secretVisible">
                <template #icon>
                  <EyeInvisibleOutlined v-if="secretVisible" />
                  <EyeOutlined v-else />
                </template>
              </a-button>
              <a-button class="api-secondary-btn api-icon-btn" :disabled="!geminiKey" @click="copySecret(geminiKey, 'Gemini Key')">
                <template #icon><CopyOutlined /></template>
              </a-button>
            </div>
          </div>
          <div>
            <div class="secret-label">通义千问 API Key</div>
            <div class="secret-input-row">
              <a-input
                v-if="tongyiSecretVisible"
                v-model:value="tongyiKey"
                class="warm-input"
                placeholder="请输入通义千问 API Key"
              />
              <div v-else class="secret-masked" @click="tongyiSecretVisible = true">
                {{ tongyiKey ? maskedTongyiKey : "暂未配置" }}
              </div>
              <a-button class="api-secondary-btn api-icon-btn" @click="tongyiSecretVisible = !tongyiSecretVisible">
                <template #icon>
                  <EyeInvisibleOutlined v-if="tongyiSecretVisible" />
                  <EyeOutlined v-else />
                </template>
              </a-button>
              <a-button class="api-secondary-btn api-icon-btn" :disabled="!tongyiKey" @click="copySecret(tongyiKey, '通义 Key')">
                <template #icon><CopyOutlined /></template>
              </a-button>
            </div>
          </div>
        </div>
        <a-button type="primary" class="api-primary-btn" :icon="h(SaveOutlined)" :loading="secretSaving" @click="handleSaveSecrets">
          保存接口密钥
        </a-button>
      </a-card>

      <a-card title="接口配置" class="warm-card warm-table-card api-card motion-fade-up motion-card-lift" style="--motion-delay: 120ms">
        <template #extra>
          <a-space>
            <a-select v-model:value="configGroupFilter" class="warm-select" style="width: 180px">
              <a-select-option value="all">全部分组</a-select-option>
              <a-select-option v-for="group in groupOptions" :key="group" :value="group">
                {{ group }}
              </a-select-option>
            </a-select>
            <a-button type="primary" class="api-primary-btn" :icon="h(PlusOutlined)" @click="openCreate">
              新增接口
            </a-button>
          </a-space>
        </template>

        <a-table
          row-key="id"
          :columns="configColumns"
          :data-source="filteredConfigs"
          :loading="loading"
          :pagination="{ pageSize: 10, class: 'warm-pagination' }"
          :scroll="{ x: 980 }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.dataIndex === 'group_name'">
              <a-tag class="api-tag api-tag-group">{{ record.group_name || "未分组" }}</a-tag>
            </template>
            <template v-else-if="column.dataIndex === 'status'">
              <a-tag class="api-tag" :class="record.status === 'enabled' ? 'api-tag-enabled' : 'api-tag-muted'">
                {{ record.status === "enabled" ? "启用" : "停用" }}
              </a-tag>
            </template>
            <template v-else-if="column.key === 'action'">
              <a-space>
                <a-button size="small" class="api-secondary-btn" :icon="h(EditOutlined)" @click="openEdit(record)">编辑</a-button>
                <a-button size="small" class="api-secondary-btn" :icon="h(CopyOutlined)" @click="openCopy(record)">复制新增</a-button>
                <a-button size="small" :class="record.status === 'enabled' ? 'api-danger-btn' : 'api-secondary-btn'" @click="handleToggleStatus(record)">
                  {{ record.status === "enabled" ? "停用" : "启用" }}
                </a-button>
              </a-space>
            </template>
          </template>
        </a-table>
      </a-card>

      <a-card title="场景绑定" class="warm-card warm-table-card api-card motion-fade-up motion-card-lift" style="--motion-delay: 200ms">
        <template #extra>
          <a-select v-model:value="bindingGroupFilter" class="warm-select" style="width: 180px">
            <a-select-option value="all">全部分组</a-select-option>
            <a-select-option v-for="group in groupOptions" :key="group" :value="group">
              {{ group }}
            </a-select-option>
          </a-select>
        </template>

        <a-alert
          class="warm-alert"
          type="info"
          show-icon
          message="调用场景固定内置，接口分组只用于页面筛选，不影响实际调用逻辑。"
          style="margin-bottom: 16px"
        />

        <a-table
          row-key="scene_key"
          :columns="bindingColumns"
          :data-source="sceneBindings"
          :loading="loading"
          :pagination="false"
          :scroll="{ x: 1240 }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'scene'">
              <div class="scene-title">{{ record.scene_label }}</div>
              <div class="scene-desc">{{ record.scene_description }}</div>
            </template>
            <template v-else-if="column.key === 'copy'">
              <div class="binding-copy-cell">
                <a-input
                  v-model:value="record.display_name"
                  class="warm-input"
                  placeholder="显示名称，为空则使用默认名称"
                />
                <a-input
                  v-model:value="record.subtitle"
                  class="warm-input"
                  placeholder="副标题，为空则使用默认副标题"
                />
                <a-button
                  size="small"
                  class="api-secondary-btn"
                  :loading="bindingSavingKey === record.scene_key"
                  @click="handleBindingChange(record.scene_key, buildBindingPayload(record))"
                >
                  保存文案
                </a-button>
              </div>
            </template>
            <template v-else-if="column.key === 'current'">
              <div v-if="record.api_config_name">
                <div>{{ record.api_config_name }}</div>
                <a-space size="small">
                  <a-tag class="api-tag api-tag-group">{{ record.api_group_name || "未分组" }}</a-tag>
                  <a-tag class="api-tag" :class="record.api_status === 'enabled' ? 'api-tag-enabled' : 'api-tag-muted'">
                    {{ record.api_status === "enabled" ? "启用" : "停用" }}
                  </a-tag>
                </a-space>
              </div>
              <span v-else class="scene-desc">未绑定</span>
            </template>
            <template v-else-if="column.key === 'bind'">
              <a-select
                :value="record.api_config_id ?? undefined"
                class="warm-select"
                allow-clear
                placeholder="请选择接口"
                style="width: 320px"
                :loading="bindingSavingKey === record.scene_key"
                @change="(value: number | undefined) => handleBindingChange(record.scene_key, buildBindingPayload(record, { api_config_id: value ?? null }))"
              >
                <a-select-option
                  v-for="option in getBindingOptions()"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </a-select-option>
              </a-select>
            </template>
            <template v-else-if="column.key === 'credit'">
              <a-input-number
                :value="record.credit_cost"
                class="warm-input-number"
                :min="0"
                :precision="0"
                :disabled="bindingSavingKey === record.scene_key"
                @change="(value: number | null) => handleBindingChange(record.scene_key, buildBindingPayload(record, { credit_cost: Number(value ?? 0) }))"
              />
              <span class="credit-unit">积分</span>
            </template>
          </template>
        </a-table>
      </a-card>

      <a-card title="占位符用法" class="warm-card api-card motion-fade-up motion-card-lift" style="--motion-delay: 280ms">
        <a-collapse class="warm-collapse">
          <a-collapse-panel key="common" header="通用占位符">
            <div class="doc-block">
              <div>可用于 Header JSON 或 请求 JSON：</div>
              <pre v-pre>{{ api_key }}</pre>
              <pre v-pre>{{ bearer_token }}</pre>
              <pre v-pre>{{ prompt }}</pre>
              <pre v-pre>{{ aspect_ratio }}</pre>
              <pre v-pre>{{ image_size }}</pre>
              <pre v-pre>{{ mode }}</pre>
            </div>
          </a-collapse-panel>
          <a-collapse-panel key="image" header="图片生成相关">
            <div class="doc-block">
              <div>用于文生图/图编辑接口：</div>
              <pre v-pre>{{ contents_parts }}</pre>
              <pre v-pre>{{ generation_config }}</pre>
            </div>
          </a-collapse-panel>
          <a-collapse-panel key="reverse" header="提示词反推相关">
            <div class="doc-block">
              <div>用于反推接口：</div>
              <pre v-pre>{{ image_data_url }}</pre>
              <pre v-pre>{{ prompt_reverse_text }}</pre>
            </div>
          </a-collapse-panel>
        </a-collapse>
      </a-card>
    </a-space>

    <a-modal
      v-model:open="modalOpen"
      :title="modalTitle"
      :mask-closable="false"
      :width="860"
      @ok="handleSave"
    >
      <a-form layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="配置名称" required>
              <a-input v-model:value="form.name" class="warm-input" placeholder="例如：Banana 主接口" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="接口分组">
              <a-input v-model:value="form.group_name" class="warm-input" placeholder="例如：Banana 系列 / 反推接口" />
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="描述">
          <a-input v-model:value="form.description" class="warm-input" placeholder="可选，用于备注该接口用途" />
        </a-form-item>

        <a-form-item label="请求地址" required>
          <a-input v-model:value="form.request_url" class="warm-input" placeholder="https://example.com/api" />
        </a-form-item>

        <a-form-item label="Header JSON" required>
          <a-textarea v-model:value="form.headers_json" class="warm-textarea" :rows="7" />
        </a-form-item>

        <a-form-item label="请求 JSON" required>
          <a-textarea v-model:value="form.payload_json" class="warm-textarea" :rows="12" />
        </a-form-item>

        <a-form-item label="状态">
          <a-radio-group v-model:value="form.status" class="warm-radio-group" button-style="solid">
            <a-radio-button value="enabled">启用</a-radio-button>
            <a-radio-button value="disabled">停用</a-radio-button>
          </a-radio-group>
        </a-form-item>
      </a-form>

      <template #footer>
        <a-space>
          <a-button class="api-secondary-btn" @click="modalOpen = false">取消</a-button>
          <a-button class="api-secondary-btn" :loading="testing" @click="handleTestConnection">测试连接</a-button>
          <a-button type="primary" class="api-primary-btn" :loading="saving" @click="handleSave">保存</a-button>
        </a-space>
      </template>
    </a-modal>
  </div>
</template>

<style scoped>
.page {
  padding: 4px;
}

.api-card :deep(.ant-card-head) {
  border-bottom: 1px solid #f0dfbe;
  background: linear-gradient(180deg, rgba(255, 250, 240, 0.88), rgba(255, 255, 255, 0.22));
}

.api-card :deep(.ant-card-head-title) {
  color: #5d4526;
  font-weight: 700;
}

.api-card :deep(.ant-card-body) {
  padding: 20px;
}

.secret-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
  margin-bottom: 16px;
}

.secret-label {
  margin-bottom: 8px;
  font-weight: 600;
}

.secret-input-row {
  display: flex;
  gap: 8px;
}

.api-primary-btn {
  border-color: #df8b1d !important;
  background: linear-gradient(135deg, #f2a533 0%, #df8b1d 100%) !important;
  color: #fff8eb !important;
  border-radius: 12px !important;
  font-weight: 600;
}

.api-primary-btn:hover,
.api-primary-btn:focus {
  border-color: #c7770d !important;
  background: linear-gradient(135deg, #f5b24c 0%, #e49729 100%) !important;
  color: #ffffff !important;
}

.api-secondary-btn {
  border-color: #efc784 !important;
  background: #fff7e8 !important;
  color: #b16d10 !important;
  border-radius: 12px !important;
  font-weight: 600;
}

.api-secondary-btn:hover,
.api-secondary-btn:focus {
  border-color: #e1a64a !important;
  background: #fff0d3 !important;
  color: #c7770d !important;
}

.api-danger-btn {
  border-color: #efb5ae !important;
  background: #fff1ef !important;
  color: #d6574b !important;
  border-radius: 12px !important;
  font-weight: 600;
}

.api-danger-btn:hover,
.api-danger-btn:focus {
  border-color: #e28980 !important;
  background: #ffe5e1 !important;
  color: #c9483d !important;
}

.api-icon-btn {
  padding-inline: 10px;
}

.secret-masked {
  min-height: 32px;
  flex: 1;
  display: flex;
  align-items: center;
  padding: 4px 11px;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  background: #fafafa;
  cursor: pointer;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}

.api-tag {
  border-radius: 999px;
  border-width: 1px;
  font-weight: 600;
}

.api-tag-group {
  color: #c7770d;
  background: #fff4df;
  border-color: #efc784;
}

.api-tag-enabled {
  color: #b16d10;
  background: #fff1d9;
  border-color: #efc784;
}

.api-tag-muted {
  color: #8f7558;
  background: #fffaf2;
  border-color: #f2e3c6;
}

.scene-title {
  font-weight: 600;
}

.scene-desc {
  color: rgba(0, 0, 0, 0.45);
  font-size: 12px;
}

.binding-copy-cell {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.doc-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.doc-block pre {
  margin: 0;
  padding: 10px 12px;
  border-radius: 8px;
  background: #f5f5f5;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}

.credit-unit {
  margin-left: 8px;
  color: rgba(0, 0, 0, 0.45);
}
</style>
