<script setup lang="ts">
import { computed, h, onMounted, ref } from "vue";
import { message, Modal } from "ant-design-vue";
import { BellOutlined, DeleteOutlined, SaveOutlined, SettingOutlined, UploadOutlined } from "@ant-design/icons-vue";
import { deleteAdminConfig, getAdminConfig, setAdminConfig, testAdminDailyReportNotify } from "@/api/admin";
import { uploadReferenceImage } from "@/api/upload";
import { useAuthStore } from "@/stores/auth";

const auth = useAuthStore();
const contactQrImage = ref("");
const announcementEnabled = ref(false);
const announcementContent = ref("");
const loading = ref(false);
const saving = ref(false);
const qrUploading = ref(false);
const testingDailyReport = ref(false);
const qrInput = ref<HTMLInputElement | null>(null);

const hasConfig = computed(() => (
  Boolean(contactQrImage.value.trim() || announcementEnabled.value || announcementContent.value.trim())
));

onMounted(async () => {
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
    content: "删除后联系二维码与系统公告配置将被清空。",
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

async function handleTestDailyReport() {
  testingDailyReport.value = true;
  try {
    const result = await testAdminDailyReportNotify();
    message.success(result.sent ? "日报测试发送成功" : "日报未发送，请检查企业微信配置");
    Modal.info({
      title: "日报测试结果",
      width: 560,
      okText: "知道了",
      content: h("div", { class: "daily-report-result" }, [
        h("p", null, `发送状态：${result.sent ? "成功" : "未发送"}`),
        h("p", null, `报表日期：${result.report_date}`),
        h("p", null, `统计区间：${result.range_start} ~ ${result.range_end}`),
        h("p", null, `在线支付营业额：¥${Number(result.revenue_yuan || 0).toFixed(2)}`),
        h("p", null, `支付成功订单数：${result.paid_order_count}`),
        h("p", null, `兑换码营业额：¥${Number(result.redeem_revenue_yuan || 0).toFixed(2)}`),
        h("p", null, `兑换码使用次数：${result.redeem_used_count}`),
        h("p", null, `任务总数：${result.task_total_count}`),
        h("p", null, `成功任务数：${result.task_success_count}`),
        h("p", null, `失败任务数：${result.task_failed_count}`),
        h("p", null, `积分消耗：${result.credit_consumed}`),
      ]),
    });
  } catch (err: any) {
    message.error(err.response?.data?.detail || "日报测试发送失败");
  } finally {
    testingDailyReport.value = false;
  }
}
</script>

<template>
  <div class="general-settings-page warm-page motion-page-enter">
    <div class="warm-page-header motion-fade-up" style="--motion-delay: 40ms">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <SettingOutlined />
        </div>
        <div>
          <div class="warm-page-title">通用设置</div>
          <div class="warm-page-desc">管理联系二维码与系统公告，面向全站用户生效。</div>
        </div>
      </div>
    </div>

    <a-spin :spinning="loading">
      <div class="settings-card warm-card motion-fade-up motion-card-lift" style="--motion-delay: 120ms">
        <div class="settings-footer">
          <a-button type="primary" class="warm-primary-btn" :loading="saving" @click="handleSave">
            <template #icon><SaveOutlined /></template>
            保存
          </a-button>
          <a-button
            v-if="auth.isSuperAdmin"
            class="config-secondary-btn"
            :loading="testingDailyReport"
            @click="handleTestDailyReport"
          >
            <template #icon><BellOutlined /></template>
            测试发送日报
          </a-button>
          <a-button class="warm-danger-btn" :disabled="!hasConfig" @click="handleDelete">
            <template #icon><DeleteOutlined /></template>
            删除
          </a-button>
        </div>

        <div class="qr-section">
          <div class="settings-label">联系二维码</div>
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
          <div class="settings-label">系统公告</div>
          <a-switch
            v-model:checked="announcementEnabled"
            class="warm-switch"
            checked-children="开启"
            un-checked-children="关闭"
          />
          <a-textarea
            v-model:value="announcementContent"
            class="announcement-textarea warm-textarea"
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
.general-settings-page {
  max-width: 820px;
}

.settings-card {
  padding: 32px;
}

.settings-label {
  font-size: 13px;
  font-weight: 700;
  color: var(--theme-subtitle);
  margin-bottom: 12px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.settings-footer {
  display: flex;
  gap: 12px;
  margin-bottom: 28px;
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
  margin-top: 0;
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

:deep(.daily-report-result) {
  display: flex;
  flex-direction: column;
  gap: 8px;
  color: var(--theme-text);

  p {
    margin: 0;
    line-height: 1.7;
  }
}
</style>
