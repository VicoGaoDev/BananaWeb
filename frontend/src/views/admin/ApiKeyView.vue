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
  UploadOutlined,
} from "@ant-design/icons-vue";
import { getApiKey, setApiKey, deleteApiKey } from "@/api/admin";
import { uploadReferenceImage } from "@/api/upload";

const keyValue = ref("");
const tongyiKey = ref("");
const contactQrImage = ref("");
const announcementEnabled = ref(false);
const announcementContent = ref("");
const hasConfig = ref(false);
const loading = ref(false);
const saving = ref(false);
const visible = ref(false);
const tongyiVisible = ref(false);
const qrUploading = ref(false);
const qrInput = ref<HTMLInputElement | null>(null);

const maskedKey = computed(() => {
  if (!keyValue.value) return "";
  const k = keyValue.value;
  if (k.length <= 8) return "••••••••";
  return k.slice(0, 4) + "••••••••" + k.slice(-4);
});

const maskedTongyiKey = computed(() => {
  if (!tongyiKey.value) return "";
  const k = tongyiKey.value;
  if (k.length <= 8) return "••••••••";
  return k.slice(0, 4) + "••••••••" + k.slice(-4);
});

onMounted(async () => {
  loading.value = true;
  try {
    const res = await getApiKey();
    if (res) {
      keyValue.value = res.key || "";
      tongyiKey.value = res.tongyi_key || "";
      contactQrImage.value = res.contact_qr_image || "";
      announcementEnabled.value = !!res.announcement_enabled;
      announcementContent.value = res.announcement_content || "";
      hasConfig.value = Boolean(
        res.key
        || res.tongyi_key
        || res.contact_qr_image
        || res.announcement_enabled
        || res.announcement_content
      );
    }
  } catch {
    // no key yet
  } finally {
    loading.value = false;
  }
});

async function handleSave() {
  if (
    !keyValue.value.trim()
    && !tongyiKey.value.trim()
    && !contactQrImage.value.trim()
    && !announcementEnabled.value
    && !announcementContent.value.trim()
  ) {
    message.warning("请至少配置一项内容");
    return;
  }
  saving.value = true;
  try {
    await setApiKey({
      key: keyValue.value.trim(),
      tongyi_key: tongyiKey.value.trim(),
      contact_qr_image: contactQrImage.value,
      announcement_enabled: announcementEnabled.value,
      announcement_content: announcementContent.value.trim(),
    });
    hasConfig.value = true;
    message.success("配置保存成功");
  } catch (err: any) {
    message.error(err.response?.data?.detail || "保存失败");
  } finally {
    saving.value = false;
  }
}

function handleDelete() {
  Modal.confirm({
    title: "确认删除",
    content: "删除后当前页面中的 Gemini、通义、联系二维码与公告配置将被清空。",
    okText: "确认删除",
    okType: "danger",
    cancelText: "取消",
    async onOk() {
      try {
        await deleteApiKey();
        keyValue.value = "";
        tongyiKey.value = "";
        contactQrImage.value = "";
        announcementEnabled.value = false;
        announcementContent.value = "";
        hasConfig.value = false;
        visible.value = false;
        tongyiVisible.value = false;
        message.success("配置已删除");
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

function copyTongyiKey() {
  if (!tongyiKey.value) return;
  navigator.clipboard.writeText(tongyiKey.value).then(() => {
    message.success("已复制到剪贴板");
  });
}


function triggerQrUpload() {
  qrInput.value?.click();
}

async function handleQrUpload(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  qrUploading.value = true;
  try {
    const res = await uploadReferenceImage(file, "misc");
    contactQrImage.value = res.url;
    message.success("二维码上传成功");
  } catch (err: any) {
    message.error(err.response?.data?.detail || "二维码上传失败");
  } finally {
    qrUploading.value = false;
    input.value = "";
  }
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
          <div class="warm-page-title">配置管理</div>
          <div class="warm-page-desc">管理 Gemini、通义、联系二维码与公告配置，后端会实时读取新配置。</div>
        </div>
      </div>
    </div>

    <a-spin :spinning="loading">
      <div class="key-card warm-card">
        <div class="key-label">Gemini API Key</div>

        <div class="key-input-row">
          <a-input
            v-if="visible"
            v-model:value="keyValue"
            size="large"
            placeholder="请输入 API Key"
            class="key-input"
          />
          <div v-else class="key-masked" @click="visible = true">
            {{ keyValue ? maskedKey : "暂未配置" }}
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
          <a-button type="primary" class="warm-primary-btn" :loading="saving" @click="handleSave">
            <template #icon><SaveOutlined /></template>
            保存
          </a-button>
          <a-button class="warm-danger-btn" :disabled="!hasConfig" @click="handleDelete">
            <template #icon><DeleteOutlined /></template>
            删除
          </a-button>
        </div>

        <div class="tongyi-section">
          <div class="key-label">通义千问 API Key</div>
          <div class="key-input-row">
            <a-input
              v-if="tongyiVisible"
              v-model:value="tongyiKey"
              size="large"
              placeholder="请输入通义千问 API Key"
              class="key-input"
            />
            <div v-else class="key-masked" @click="tongyiVisible = true">
              {{ tongyiKey ? maskedTongyiKey : "暂未配置" }}
            </div>

            <div class="key-actions">
              <a-button
                type="text"
                @click="tongyiVisible = !tongyiVisible"
                :title="tongyiVisible ? '隐藏' : '显示'"
              >
                <template #icon>
                  <EyeInvisibleOutlined v-if="tongyiVisible" />
                  <EyeOutlined v-else />
                </template>
              </a-button>
              <a-button type="text" @click="copyTongyiKey" :disabled="!tongyiKey" title="复制">
                <template #icon><CopyOutlined /></template>
              </a-button>
            </div>
          </div>
        </div>

        <div class="qr-section">
          <div class="key-label">联系二维码</div>
          <div class="qr-card">
            <div v-if="contactQrImage" class="qr-preview">
              <img :src="contactQrImage" alt="contact qr code" />
            </div>
            <div v-else class="qr-placeholder">暂未上传联系二维码</div>

            <div class="qr-actions">
              <input
                ref="qrInput"
                type="file"
                accept="image/*"
                style="display: none"
                @change="handleQrUpload"
              />
              <a-button :loading="qrUploading" @click="triggerQrUpload">
                <template #icon><UploadOutlined /></template>
                {{ contactQrImage ? "重新上传" : "上传二维码" }}
              </a-button>
            </div>
          </div>
        </div>

        <div class="announcement-section">
          <div class="key-label">系统公告</div>
          <a-switch v-model:checked="announcementEnabled" checked-children="开启" un-checked-children="关闭" />
          <a-textarea
            v-model:value="announcementContent"
            class="announcement-textarea"
            :rows="6"
            :maxlength="2000"
            show-count
            placeholder="请输入系统公告内容。用户每次登录成功或刷新网站时会触发公告检查，并可选择今日不再弹出。"
          />
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

.qr-section {
  margin-top: 28px;
}

.qr-card {
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 18px 20px;
  border-radius: 20px;
  background: #fffaf1;
  border: 1px solid #f1dfbf;
}

.qr-preview {
  width: 144px;
  height: 144px;
  flex: 0 0 144px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 18px;
  overflow: hidden;
  background: #fff;
  border: 1px solid #f0dfbe;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.qr-placeholder {
  width: 144px;
  height: 144px;
  flex: 0 0 144px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  text-align: center;
  border-radius: 18px;
  background: #fffdf8;
  border: 1px dashed #e7c893;
  color: #9b7b52;
  line-height: 1.6;
}

.qr-actions {
  display: flex;
  align-items: center;
}

.announcement-section {
  margin-top: 28px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.announcement-textarea {
  :deep(textarea) {
    border-radius: 16px;
    border-color: #efdcb9;
    background: #fffdf8;
  }
}
</style>
