<script setup lang="ts">
import { ref, onMounted, computed } from "vue";
import { message, Modal } from "ant-design-vue";
import {
  KeyOutlined,
  EyeOutlined,
  EyeInvisibleOutlined,
  CopyOutlined,
  DeleteOutlined,
  SaveOutlined,
} from "@ant-design/icons-vue";
import { getApiKey, setApiKey, deleteApiKey } from "@/api/admin";

const keyValue = ref("");
const hasKey = ref(false);
const loading = ref(false);
const saving = ref(false);
const visible = ref(false);

const maskedKey = computed(() => {
  if (!keyValue.value) return "";
  const k = keyValue.value;
  if (k.length <= 8) return "••••••••";
  return k.slice(0, 4) + "••••••••" + k.slice(-4);
});

onMounted(async () => {
  loading.value = true;
  try {
    const res = await getApiKey();
    if (res && res.key) {
      keyValue.value = res.key;
      hasKey.value = true;
    }
  } catch {
    // no key yet
  } finally {
    loading.value = false;
  }
});

async function handleSave() {
  if (!keyValue.value.trim()) {
    message.warning("请输入 API Key");
    return;
  }
  saving.value = true;
  try {
    await setApiKey(keyValue.value.trim());
    hasKey.value = true;
    message.success("API Key 保存成功");
  } catch (err: any) {
    message.error(err.response?.data?.detail || "保存失败");
  } finally {
    saving.value = false;
  }
}

function handleDelete() {
  Modal.confirm({
    title: "确认删除",
    content: "删除后 API Key 将被清空，AI 生图功能将无法使用。",
    okText: "确认删除",
    okType: "danger",
    cancelText: "取消",
    async onOk() {
      try {
        await deleteApiKey();
        keyValue.value = "";
        hasKey.value = false;
        visible.value = false;
        message.success("API Key 已删除");
      } catch (err: any) {
        message.error(err.response?.data?.detail || "删除失败");
      }
    },
  });
}

function copyKey() {
  if (!keyValue.value) return;
  navigator.clipboard.writeText(keyValue.value).then(() => {
    message.success("已复制到剪贴板");
  });
}
</script>

<template>
  <div class="apikey-page warm-page">
    <div class="warm-page-header">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <KeyOutlined />
        </div>
        <div>
          <div class="warm-page-title">API Key 管理</div>
          <div class="warm-page-desc">管理 AI 生图服务的全局密钥，后端会实时读取新配置。</div>
        </div>
      </div>
    </div>

    <a-spin :spinning="loading">
      <div class="key-card warm-card">
        <div class="key-label">当前 API Key</div>

        <div class="key-input-row">
          <a-input
            v-if="visible"
            v-model:value="keyValue"
            size="large"
            placeholder="请输入 API Key"
            class="key-input"
          />
          <div v-else class="key-masked" @click="visible = true">
            {{ hasKey ? maskedKey : "暂未配置" }}
          </div>

          <div class="key-actions">
            <a-button
              type="text"
              @click="visible = !visible"
              :title="visible ? '隐藏' : '显示'"
            >
              <template #icon>
                <EyeInvisibleOutlined v-if="visible" />
                <EyeOutlined v-else />
              </template>
            </a-button>
            <a-button type="text" @click="copyKey" :disabled="!keyValue" title="复制">
              <template #icon><CopyOutlined /></template>
            </a-button>
          </div>
        </div>

        <div class="key-footer">
          <a-button type="primary" class="warm-primary-btn" :loading="saving" :disabled="!visible" @click="handleSave">
            <template #icon><SaveOutlined /></template>
            保存
          </a-button>
          <a-button class="warm-danger-btn" :disabled="!hasKey" @click="handleDelete">
            <template #icon><DeleteOutlined /></template>
            删除
          </a-button>
        </div>
      </div>
    </a-spin>
  </div>
</template>

<style scoped lang="scss">
.apikey-page {
  max-width: 820px;
}

.key-card {
  padding: 32px;
}

.key-label {
  font-size: 13px;
  font-weight: 700;
  color: #8d7457;
  margin-bottom: 12px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.key-input-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 24px;
}

.key-input {
  flex: 1;
  font-family: "SF Mono", "Consolas", "Monaco", monospace;
  letter-spacing: 0.5px;

  :deep(.ant-input) {
    border-radius: 16px;
    border-color: #efdcb9;
    background: #fffdf8;
  }
}

.key-masked {
  flex: 1;
  min-height: 48px;
  display: flex;
  align-items: center;
  padding: 0 16px;
  background: #fff8ec;
  border: 1px solid #f0dfbe;
  border-radius: 16px;
  font-family: "SF Mono", "Consolas", "Monaco", monospace;
  font-size: 14px;
  color: #80684b;
  letter-spacing: 1px;
  cursor: pointer;
  transition: all 0.2s;

  &:hover {
    border-color: #f0ba5f;
    color: #4c341a;
  }
}

.key-actions {
  display: flex;
  gap: 6px;

  :deep(.ant-btn) {
    width: 40px;
    height: 40px;
    border-radius: 14px;
    background: #fff7e6;
    border: 1px solid #f0dfbe;
    color: #7a613f;
  }
}

.key-footer {
  display: flex;
  gap: 12px;
}
</style>
