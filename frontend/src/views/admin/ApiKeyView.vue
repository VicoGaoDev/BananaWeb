<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { message, Modal } from "ant-design-vue";
import { BgColorsOutlined, DeleteOutlined, KeyOutlined, SaveOutlined, UploadOutlined } from "@ant-design/icons-vue";
import { deleteAdminConfig, getAdminConfig, setAdminConfig } from "@/api/admin";
import { appThemes, type AppThemeName } from "@/config/theme";
import { getCurrentTheme, setAppTheme } from "@/lib/theme";
import { useAuthStore } from "@/stores/auth";
import { uploadReferenceImage } from "@/api/upload";

const auth = useAuthStore();
const isSuperAdmin = computed(() => auth.isSuperAdmin);
const contactQrImage = ref("");
const announcementEnabled = ref(false);
const announcementContent = ref("");
const loading = ref(false);
const saving = ref(false);
const qrUploading = ref(false);
const qrInput = ref<HTMLInputElement | null>(null);
const currentTheme = ref<AppThemeName>(getCurrentTheme());

const themeOptions = [
  { label: appThemes.dark.label, value: appThemes.dark.key, desc: "选中菜单、主操作和整体背景走黑灰风格" },
  { label: appThemes.warm.label, value: appThemes.warm.key, desc: "恢复当前暖色橙金风格" },
] as const;

const hasConfig = computed(() => (
  Boolean(contactQrImage.value.trim() || announcementEnabled.value || announcementContent.value.trim())
));

onMounted(async () => {
  currentTheme.value = getCurrentTheme();
  loading.value = true;
  try {
    const res = await getAdminConfig();
    if (res) {
      contactQrImage.value = res.contact_qr_image || "";
      announcementEnabled.value = !!res.announcement_enabled;
      announcementContent.value = res.announcement_content || "";
    }
  } catch {
    // no config yet
  } finally {
    loading.value = false;
  }
});

function applyThemeSelection() {
  setAppTheme(currentTheme.value);
  message.success(`已切换为${appThemes[currentTheme.value].label}`);
}

async function handleSave() {
  if (!hasConfig.value) {
    message.warning("请至少配置一项内容");
    return;
  }
  saving.value = true;
  try {
    await setAdminConfig({
      contact_qr_image: contactQrImage.value,
      announcement_enabled: announcementEnabled.value,
      announcement_content: announcementContent.value.trim(),
    });
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
    content: "删除后当前页面中的联系二维码与公告配置将被清空。",
    okText: "确认删除",
    okType: "danger",
    cancelText: "取消",
    async onOk() {
      try {
        await deleteAdminConfig();
        contactQrImage.value = "";
        announcementEnabled.value = false;
        announcementContent.value = "";
        message.success("配置已删除");
      } catch (err: any) {
        message.error(err.response?.data?.detail || "删除失败");
      }
    },
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
  <div class="apikey-page warm-page motion-page-enter">
    <div class="warm-page-header motion-fade-up" style="--motion-delay: 40ms">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <KeyOutlined />
        </div>
        <div>
          <div class="warm-page-title">配置管理</div>
          <div class="warm-page-desc">管理联系二维码与系统公告。接口密钥已迁移到超级管理员的接口管理页面。</div>
        </div>
      </div>
    </div>

    <a-spin :spinning="loading">
      <div class="key-card warm-card motion-fade-up motion-card-lift" style="--motion-delay: 140ms">
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
              <a-button class="config-secondary-btn" :loading="qrUploading" @click="triggerQrUpload">
                <template #icon><UploadOutlined /></template>
                {{ contactQrImage ? "重新上传" : "上传二维码" }}
              </a-button>
            </div>
          </div>
        </div>

        <div class="announcement-section">
          <div class="key-label">系统公告</div>
          <a-switch v-model:checked="announcementEnabled" class="warm-switch" checked-children="开启" un-checked-children="关闭" />
          <a-textarea
            v-model:value="announcementContent"
            class="announcement-textarea warm-textarea"
            :rows="6"
            :maxlength="2000"
            show-count
            placeholder="请输入系统公告内容。用户每次登录成功或刷新网站时会触发公告检查，并可选择今日不再弹出。"
          />
        </div>

        <div v-if="isSuperAdmin" class="theme-section">
          <div class="theme-section-head">
            <div>
              <div class="key-label">前端主题风格</div>
              <div class="theme-tip">仅作用于当前浏览器，本地保存。刷新或重新打开后会继续使用所选主题。</div>
            </div>
            <BgColorsOutlined class="theme-section-icon" />
          </div>

          <a-radio-group
            v-model:value="currentTheme"
            class="warm-radio-group theme-radio-group"
            button-style="solid"
          >
            <a-radio-button
              v-for="option in themeOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </a-radio-button>
          </a-radio-group>

          <div class="theme-option-list">
            <div
              v-for="option in themeOptions"
              :key="option.value"
              class="theme-option-card"
              :class="{ active: currentTheme === option.value }"
            >
              <div class="theme-option-title">{{ option.label }}</div>
              <div class="theme-option-desc">{{ option.desc }}</div>
            </div>
          </div>

          <div class="theme-actions">
            <a-button type="primary" class="warm-primary-btn" @click="applyThemeSelection">
              应用主题
            </a-button>
          </div>
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
  color: var(--theme-subtitle);
  margin-bottom: 12px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.key-footer {
  display: flex;
  gap: 12px;
}

.config-secondary-btn {
  border-color: var(--theme-panel-border-strong) !important;
  background: var(--theme-panel-bg-strong) !important;
  color: var(--theme-accent-text) !important;
  border-radius: 12px !important;
  font-weight: 600;
}

.config-secondary-btn:hover,
.config-secondary-btn:focus {
  border-color: var(--theme-border-strong) !important;
  background: var(--theme-control-hover-bg) !important;
  color: var(--theme-accent-text-hover) !important;
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
  background: var(--theme-panel-bg-soft);
  border: 1px solid var(--theme-panel-border);
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
  background: var(--theme-empty-bg);
  border: 1px solid var(--theme-border);

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
  background: var(--theme-control-bg);
  border: 1px dashed var(--theme-empty-border);
  color: var(--text-secondary);
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
    border-color: var(--theme-control-border);
    background: var(--theme-control-bg);
  }
}

.theme-section {
  margin-top: 28px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 22px 24px;
  border-radius: 22px;
  background: linear-gradient(180deg, var(--theme-panel-bg), var(--theme-panel-bg-soft));
  border: 1px solid var(--theme-panel-border);
}

.theme-section-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.theme-section-icon {
  font-size: 22px;
  color: var(--theme-accent-text);
}

.theme-tip {
  color: var(--text-secondary);
  line-height: 1.6;
  font-size: 13px;
}

.theme-radio-group {
  width: fit-content;
}

.theme-option-list {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.theme-option-card {
  padding: 16px 18px;
  border-radius: 18px;
  border: 1px solid var(--theme-panel-border);
  background: var(--theme-panel-bg-muted);
  transition:
    border-color var(--motion-duration-base) var(--motion-ease-soft),
    background var(--motion-duration-base) var(--motion-ease-soft),
    box-shadow var(--motion-duration-base) var(--motion-ease-soft);
}

.theme-option-card.active {
  border-color: var(--theme-border-strong);
  background: var(--theme-control-hover-bg);
  box-shadow: 0 12px 24px var(--theme-card-shadow);
}

.theme-option-title {
  color: var(--theme-title);
  font-weight: 700;
}

.theme-option-desc {
  margin-top: 6px;
  color: var(--text-secondary);
  line-height: 1.6;
  font-size: 13px;
}

.theme-actions {
  display: flex;
  justify-content: flex-end;
}

@media (max-width: 720px) {
  .theme-option-list {
    grid-template-columns: 1fr;
  }
}
</style>
