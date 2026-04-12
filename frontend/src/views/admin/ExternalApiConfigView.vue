<script setup lang="ts">
import { computed, h, onMounted, reactive, ref } from "vue";
import { message, Modal } from "ant-design-vue";
import { EditOutlined, PlusOutlined } from "@ant-design/icons-vue";
import {
  createExternalApiConfig,
  listExternalApiConfigs,
  listExternalApiSceneBindings,
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
const saving = ref(false);
const testing = ref(false);
const bindingSavingKey = ref("");
const modalOpen = ref(false);
const editingId = ref<number | null>(null);
const configGroupFilter = ref("all");
const bindingGroupFilter = ref("all");

const configColumns = [
  { title: "名称", dataIndex: "name", width: 180 },
  { title: "分组", dataIndex: "group_name", width: 140 },
  { title: "请求地址", dataIndex: "request_url", ellipsis: true },
  { title: "状态", dataIndex: "status", width: 100 },
  { title: "更新时间", dataIndex: "updated_at", width: 180 },
  { title: "操作", key: "action", width: 180 },
];

const bindingColumns = [
  { title: "调用场景", key: "scene", width: 220 },
  { title: "当前绑定接口", key: "current", width: 220 },
  { title: "选择接口", key: "bind" },
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

const modalTitle = computed(() => (editingId.value ? "编辑接口配置" : "新增接口配置"));
const groupOptions = computed(() => {
  const groups = Array.from(new Set(configs.value.map((item) => item.group_name || "未分组").filter(Boolean)));
  return groups.sort((a, b) => a.localeCompare(b, "zh-CN"));
});
const filteredConfigs = computed(() => (
  configGroupFilter.value === "all"
    ? configs.value
    : configs.value.filter((item) => item.group_name === configGroupFilter.value)
));

function resetForm() {
  editingId.value = null;
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
  form.name = item.name;
  form.description = item.description || "";
  form.group_name = item.group_name || "默认";
  form.request_url = item.request_url;
  form.headers_json = item.headers_json;
  form.payload_json = item.payload_json;
  form.status = item.status;
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
    const [configRows, bindingRows] = await Promise.all([
      listExternalApiConfigs(),
      listExternalApiSceneBindings(),
    ]);
    configs.value = configRows;
    sceneBindings.value = bindingRows;
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

async function handleBindingChange(sceneKey: ExternalApiSceneBinding["scene_key"], apiConfigId: number | null) {
  bindingSavingKey.value = sceneKey;
  try {
    await updateExternalApiSceneBinding(sceneKey, apiConfigId);
    message.success("场景绑定已更新");
    await load();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "更新绑定失败");
  } finally {
    bindingSavingKey.value = "";
  }
}
</script>

<template>
  <div class="page">
    <a-space direction="vertical" :size="16" style="width: 100%">
      <a-card title="接口配置">
        <template #extra>
          <a-space>
            <a-select v-model:value="configGroupFilter" style="width: 180px">
              <a-select-option value="all">全部分组</a-select-option>
              <a-select-option v-for="group in groupOptions" :key="group" :value="group">
                {{ group }}
              </a-select-option>
            </a-select>
            <a-button type="primary" :icon="h(PlusOutlined)" @click="openCreate">
              新增接口
            </a-button>
          </a-space>
        </template>

        <a-table
          row-key="id"
          :columns="configColumns"
          :data-source="filteredConfigs"
          :loading="loading"
          :pagination="{ pageSize: 10 }"
          :scroll="{ x: 980 }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.dataIndex === 'group_name'">
              <a-tag color="blue">{{ record.group_name || "未分组" }}</a-tag>
            </template>
            <template v-else-if="column.dataIndex === 'status'">
              <a-tag :color="record.status === 'enabled' ? 'green' : 'default'">
                {{ record.status === "enabled" ? "启用" : "停用" }}
              </a-tag>
            </template>
            <template v-else-if="column.key === 'action'">
              <a-space>
                <a-button size="small" :icon="h(EditOutlined)" @click="openEdit(record)">编辑</a-button>
                <a-button size="small" @click="handleToggleStatus(record)">
                  {{ record.status === "enabled" ? "停用" : "启用" }}
                </a-button>
              </a-space>
            </template>
          </template>
        </a-table>
      </a-card>

      <a-card title="场景绑定">
        <template #extra>
          <a-select v-model:value="bindingGroupFilter" style="width: 180px">
            <a-select-option value="all">全部分组</a-select-option>
            <a-select-option v-for="group in groupOptions" :key="group" :value="group">
              {{ group }}
            </a-select-option>
          </a-select>
        </template>

        <a-alert
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
          :scroll="{ x: 900 }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'scene'">
              <div class="scene-title">{{ record.scene_label }}</div>
              <div class="scene-desc">{{ record.scene_description }}</div>
            </template>
            <template v-else-if="column.key === 'current'">
              <div v-if="record.api_config_name">
                <div>{{ record.api_config_name }}</div>
                <a-space size="small">
                  <a-tag color="blue">{{ record.api_group_name || "未分组" }}</a-tag>
                  <a-tag :color="record.api_status === 'enabled' ? 'green' : 'default'">
                    {{ record.api_status === "enabled" ? "启用" : "停用" }}
                  </a-tag>
                </a-space>
              </div>
              <span v-else class="scene-desc">未绑定</span>
            </template>
            <template v-else-if="column.key === 'bind'">
              <a-select
                :value="record.api_config_id ?? undefined"
                allow-clear
                placeholder="请选择接口"
                style="width: 320px"
                :loading="bindingSavingKey === record.scene_key"
                @change="(value: number | undefined) => handleBindingChange(record.scene_key, value ?? null)"
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
          </template>
        </a-table>
      </a-card>

      <a-card title="占位符用法">
        <a-collapse>
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
              <a-input v-model:value="form.name" placeholder="例如：Banana 主接口" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="接口分组">
              <a-input v-model:value="form.group_name" placeholder="例如：Banana 系列 / 反推接口" />
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="描述">
          <a-input v-model:value="form.description" placeholder="可选，用于备注该接口用途" />
        </a-form-item>

        <a-form-item label="请求地址" required>
          <a-input v-model:value="form.request_url" placeholder="https://example.com/api" />
        </a-form-item>

        <a-form-item label="Header JSON" required>
          <a-textarea v-model:value="form.headers_json" :rows="7" />
        </a-form-item>

        <a-form-item label="请求 JSON" required>
          <a-textarea v-model:value="form.payload_json" :rows="12" />
        </a-form-item>

        <a-form-item label="状态">
          <a-radio-group v-model:value="form.status">
            <a-radio value="enabled">启用</a-radio>
            <a-radio value="disabled">停用</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>

      <template #footer>
        <a-space>
          <a-button @click="modalOpen = false">取消</a-button>
          <a-button :loading="testing" @click="handleTestConnection">测试连接</a-button>
          <a-button type="primary" :loading="saving" @click="handleSave">保存</a-button>
        </a-space>
      </template>
    </a-modal>
  </div>
</template>

<style scoped>
.page {
  padding: 4px;
}

.scene-title {
  font-weight: 600;
}

.scene-desc {
  color: rgba(0, 0, 0, 0.45);
  font-size: 12px;
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
</style>
