<script setup lang="ts">
import { h, onMounted, reactive, ref } from "vue";
import { message, Modal } from "ant-design-vue";
import dayjs from "dayjs";
import type { Dayjs } from "dayjs";
import { AccountBookOutlined, BellOutlined, PlusOutlined } from "@ant-design/icons-vue";
import {
  createOfflineOrder,
  getAdminAnalyticsOfflineOrderRevenue,
  getAdminAnalyticsPaymentRevenue,
  getAdminAnalyticsRedeemRevenue,
  listUsers,
  testAdminDailyReportNotify,
} from "@/api/admin";
import { isSessionExpiredError } from "@/lib/authError";
import { useAuthStore } from "@/stores/auth";
import RedeemRevenueTable from "@/components/admin/RedeemRevenueTable.vue";
import type { AdminAnalyticsRedeemRevenue, AdminUser } from "@/types";

type DatePreset = "today" | "3d" | "7d" | "30d";

const auth = useAuthStore();
const loading = ref(false);
const sendingDailyReport = ref(false);
const creatingOfflineOrder = ref(false);
const offlineOrderModalOpen = ref(false);
const preset = ref<DatePreset | undefined>("today");
const dateRange = ref<[Dayjs, Dayjs] | null>(null);
const redeemRevenue = ref<AdminAnalyticsRedeemRevenue | null>(null);
const paymentRevenue = ref<AdminAnalyticsRedeemRevenue | null>(null);
const offlineOrderRevenue = ref<AdminAnalyticsRedeemRevenue | null>(null);
const users = ref<AdminUser[]>([]);
const offlineOrderForm = reactive({
  user_id: undefined as string | undefined,
  credit_amount: 0,
  amount_yuan: undefined as number | undefined,
  remark: "",
});

function formatQueryDate(value?: Dayjs) {
  return value ? value.format("YYYY-MM-DDTHH:mm:ss") : undefined;
}

function applyPreset(nextPreset: DatePreset) {
  const now = dayjs();
  preset.value = nextPreset;
  if (nextPreset === "today") {
    dateRange.value = [now.startOf("day"), now.endOf("day")];
    return;
  }
  if (nextPreset === "3d") {
    dateRange.value = [now.subtract(2, "day").startOf("day"), now.endOf("day")];
    return;
  }
  if (nextPreset === "7d") {
    dateRange.value = [now.subtract(6, "day").startOf("day"), now.endOf("day")];
    return;
  }
  dateRange.value = [now.subtract(29, "day").startOf("day"), now.endOf("day")];
}

function handlePresetChange(value: DatePreset) {
  applyPreset(value);
  load();
}

function handleDateRangeChange() {
  preset.value = undefined;
  if (dateRange.value?.[0] && dateRange.value?.[1]) {
    load();
  }
}

function handleReset() {
  applyPreset("today");
  load();
}

async function handleSendDailyReport() {
  sendingDailyReport.value = true;
  try {
    const result = await testAdminDailyReportNotify();
    message.success(result.sent ? "日报发送成功" : "日报未发送，请检查企业微信配置");
    Modal.info({
      title: "日报发送结果",
      width: 560,
      okText: "知道了",
      content: h("div", { class: "daily-report-result" }, [
        h("p", null, `发送状态：${result.sent ? "成功" : "未发送"}`),
        h("p", null, `报表日期：${result.report_date}`),
        h("p", null, `统计区间：${result.range_start} ~ ${result.range_end}`),
        h("p", null, `在线支付营业额：¥${Number(result.revenue_yuan || 0).toFixed(2)}`),
        h("p", null, `支付成功订单数：${result.paid_order_count}`),
        h("p", null, `线下订单营业额：¥${Number(result.offline_order_revenue_yuan || 0).toFixed(2)}`),
        h("p", null, `线下订单录入数：${result.offline_order_count}`),
        h("p", null, `兑换码营业额：¥${Number(result.redeem_revenue_yuan || 0).toFixed(2)}`),
        h("p", null, `兑换码使用次数：${result.redeem_used_count}`),
        h("p", null, `任务总数：${result.task_total_count}`),
        h("p", null, `成功任务数：${result.task_success_count}`),
        h("p", null, `失败任务数：${result.task_failed_count}`),
        h("p", null, `积分消耗：${result.credit_consumed}`),
      ]),
    });
  } catch (err: unknown) {
    if (isSessionExpiredError(err)) return;
    message.error((err as any)?.response?.data?.detail || "发送日报失败");
  } finally {
    sendingDailyReport.value = false;
  }
}

async function load() {
  if (!dateRange.value?.[0] || !dateRange.value?.[1]) {
    return;
  }
  loading.value = true;
  try {
    const query = {
      granularity: "day",
      start_date: formatQueryDate(dateRange.value[0].startOf("day")),
      end_date: formatQueryDate(dateRange.value[1].endOf("day")),
    } as const;
    const [redeemResult, paymentResult, offlineOrderResult] = await Promise.all([
      getAdminAnalyticsRedeemRevenue(query),
      getAdminAnalyticsPaymentRevenue(query),
      getAdminAnalyticsOfflineOrderRevenue(query),
    ]);
    redeemRevenue.value = redeemResult;
    paymentRevenue.value = paymentResult;
    offlineOrderRevenue.value = offlineOrderResult;
  } catch (err: unknown) {
    if (isSessionExpiredError(err)) return;
    message.error("获取营业额数据失败");
  } finally {
    loading.value = false;
  }
}

async function loadUsers() {
  try {
    users.value = await listUsers();
  } catch (err: unknown) {
    if (isSessionExpiredError(err)) return;
    message.error("获取用户列表失败");
  }
}

function openOfflineOrderModal() {
  offlineOrderForm.user_id = undefined;
  offlineOrderForm.credit_amount = 0;
  offlineOrderForm.amount_yuan = undefined;
  offlineOrderForm.remark = "";
  offlineOrderModalOpen.value = true;
}

async function handleCreateOfflineOrder() {
  if (!offlineOrderForm.user_id) {
    message.warning("请选择用户");
    return;
  }
  if (!offlineOrderForm.credit_amount || offlineOrderForm.credit_amount <= 0) {
    message.warning("请输入有效积分");
    return;
  }
  if (offlineOrderForm.amount_yuan === undefined || offlineOrderForm.amount_yuan === null || offlineOrderForm.amount_yuan <= 0) {
    message.warning("请输入有效金额");
    return;
  }
  creatingOfflineOrder.value = true;
  try {
    await createOfflineOrder({
      user_id: offlineOrderForm.user_id,
      credit_amount: offlineOrderForm.credit_amount,
      amount_yuan: Number(offlineOrderForm.amount_yuan),
      remark: offlineOrderForm.remark.trim(),
    });
    message.success("线下订单录入成功");
    offlineOrderModalOpen.value = false;
    await load();
  } catch (err: unknown) {
    if (isSessionExpiredError(err)) return;
    message.error((err as any)?.response?.data?.detail || "线下订单录入失败");
  } finally {
    creatingOfflineOrder.value = false;
  }
}

onMounted(() => {
  applyPreset("today");
  loadUsers();
  load();
});
</script>

<template>
  <div class="warm-page motion-page-enter">
    <div class="warm-page-header motion-fade-up" style="--motion-delay: 40ms">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <AccountBookOutlined />
        </div>
        <div>
          <div class="warm-page-title">营业额</div>
          <div class="warm-page-desc">统计在线购买与积分兑换码营业额，支持按时间区间筛选。</div>
        </div>
      </div>
      <a-button
        v-if="auth.isAdmin"
        type="primary"
        class="warm-primary-btn"
        @click="openOfflineOrderModal"
      >
        <template #icon><PlusOutlined /></template>
        录入线下订单
      </a-button>
      <a-button
        v-if="auth.isSuperAdmin"
        type="primary"
        class="warm-primary-btn revenue-header-btn"
        :loading="sendingDailyReport"
        @click="handleSendDailyReport"
      >
        <template #icon><BellOutlined /></template>
        发送日报到企业微信
      </a-button>
    </div>

    <div class="analytics-filter warm-card motion-fade-up motion-card-lift" style="--motion-delay: 120ms">
      <div class="analytics-filter-row">
        <a-range-picker
          v-model:value="dateRange"
          :placeholder="['开始日期', '结束日期']"
          class="analytics-filter-date"
          @change="handleDateRangeChange"
        />
        <div class="analytics-filter-panel-compact">
          <a-radio-group
            :value="preset"
            class="analytics-segmented-group analytics-segmented-group-secondary"
            button-style="solid"
            @update:value="handlePresetChange"
          >
            <a-radio-button value="today">今日</a-radio-button>
            <a-radio-button value="3d">近 3 天</a-radio-button>
            <a-radio-button value="7d">近 7 天</a-radio-button>
            <a-radio-button value="30d">近 30 天</a-radio-button>
          </a-radio-group>
        </div>
        <a-button type="primary" class="analytics-action-btn" :loading="loading" @click="load">查询</a-button>
        <a-button class="analytics-action-btn analytics-action-btn-secondary" @click="handleReset">重置</a-button>
      </div>
    </div>

    <div class="revenue-section-stack">
      <RedeemRevenueTable
        :data="paymentRevenue"
        :loading="loading"
        title="在线购买营业额"
        count-label="购买"
      />
      <RedeemRevenueTable
        :data="redeemRevenue"
        :loading="loading"
        title="兑换码营业额"
        count-label="兑换"
      />
      <RedeemRevenueTable
        :data="offlineOrderRevenue"
        :loading="loading"
        title="线下订单营业额"
        count-label="录入"
      />
    </div>

    <a-modal
      v-model:open="offlineOrderModalOpen"
      title="录入线下订单"
      ok-text="提交"
      cancel-text="取消"
      :confirm-loading="creatingOfflineOrder"
      @ok="handleCreateOfflineOrder"
    >
      <a-form layout="vertical">
        <a-form-item label="用户">
          <a-select
            v-model:value="offlineOrderForm.user_id"
            show-search
            placeholder="请选择用户"
            option-filter-prop="label"
            :options="users.map((user) => ({
              label: user.email ? `${user.username} (${user.email})` : `${user.username} (${user.id})`,
              value: user.id,
            }))"
          />
        </a-form-item>
        <a-form-item label="积分">
          <a-input-number
            v-model:value="offlineOrderForm.credit_amount"
            :min="1"
            :precision="0"
            style="width: 100%"
            placeholder="请输入积分"
          />
        </a-form-item>
        <a-form-item label="金额（人民币元）">
          <a-input-number
            v-model:value="offlineOrderForm.amount_yuan"
            :min="0.01"
            :precision="2"
            style="width: 100%"
            placeholder="请输入金额，例如 19.90"
          />
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea
            v-model:value="offlineOrderForm.remark"
            :rows="3"
            :maxlength="500"
            placeholder="可选，填写线下订单备注"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<style scoped lang="scss">
.analytics-filter {
  margin-bottom: 16px;
}

.revenue-section-stack {
  display: grid;
  gap: 16px;
}

.revenue-header-btn {
  min-width: 180px;
  margin-left: auto;
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

@media (max-width: 768px) {
  .analytics-filter-row {
    align-items: stretch;
  }

  .analytics-filter-date,
  .analytics-action-btn {
    width: 100%;
  }

  .revenue-header-btn {
    width: 100%;
    margin-left: 0;
  }
}
</style>
