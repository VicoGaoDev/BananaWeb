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
  <div class="apikey-page">
    <div class="page-header">
      <h2><KeyOutlined /> API Key 管理</h2>
      <p class="page-desc">管理 AI 生图服务的 API Key，系统全局使用同一个 Key</p>
    </div>

    <a-spin :spinning="loading">
      <div class="key-card dashboard-card">
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
          <a-button
            type="primary"
            :loading="saving"
            :disabled="!visible"
            @click="handleSave"
          >
            <template #icon><SaveOutlined /></template>
            保存
          </a-button>
          <a-button danger :disabled="!hasKey" @click="handleDelete">
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
  max-width: 640px;
}

.page-header {
  margin-bottom: 24px;

  h2 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text);
    margin-bottom: 4px;
  }
}

.page-desc {
  font-size: 13px;
  color: var(--text-secondary);
}

.key-card {
  padding: 32px;
}

.key-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 12px;
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
}

.key-masked {
  flex: 1;
  height: 40px;
  display: flex;
  align-items: center;
  padding: 0 12px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  font-family: "SF Mono", "Consolas", "Monaco", monospace;
  font-size: 14px;
  color: var(--text-secondary);
  letter-spacing: 1px;
  cursor: pointer;
  transition: all 0.2s;

  &:hover {
    border-color: var(--primary);
    color: var(--text);
  }
}

.key-actions {
  display: flex;
  gap: 2px;
}

.key-footer {
  display: flex;
  gap: 12px;
}
</style>
