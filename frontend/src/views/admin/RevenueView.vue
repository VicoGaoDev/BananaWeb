<script setup lang="ts">
import { inject, onMounted, ref } from "vue";
import { message } from "ant-design-vue";
import dayjs from "dayjs";
import type { Dayjs } from "dayjs";
import { AccountBookOutlined, ThunderboltOutlined } from "@ant-design/icons-vue";
import { getAdminAnalyticsRedeemRevenue } from "@/api/admin";
import { isSessionExpiredError } from "@/lib/authError";
import RedeemRevenueTable from "@/components/admin/RedeemRevenueTable.vue";
import type { AdminAnalyticsRedeemRevenue } from "@/types";

type DatePreset = "today" | "3d" | "7d" | "30d";

const loading = ref(false);
const preset = ref<DatePreset | undefined>("today");
const dateRange = ref<[Dayjs, Dayjs] | null>(null);
const redeemRevenue = ref<AdminAnalyticsRedeemRevenue | null>(null);
const openPurchaseEntry = inject<() => void>("openPurchaseEntry");

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

function handleOpenPurchase() {
  openPurchaseEntry?.();
}

async function load() {
  if (!dateRange.value?.[0] || !dateRange.value?.[1]) {
    return;
  }
  loading.value = true;
  try {
    redeemRevenue.value = await getAdminAnalyticsRedeemRevenue({
      granularity: "day",
      start_date: formatQueryDate(dateRange.value[0].startOf("day")),
      end_date: formatQueryDate(dateRange.value[1].endOf("day")),
    });
  } catch (err: unknown) {
    if (isSessionExpiredError(err)) return;
    message.error("获取营业额数据失败");
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  applyPreset("today");
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
          <div class="warm-page-desc">按积分兑换码面值统计已兑换数量与对应售价金额，支持按时间区间筛选。</div>
        </div>
      </div>
      <a-button type="primary" class="revenue-purchase-entry" @click="handleOpenPurchase">
        <template #icon><ThunderboltOutlined /></template>
        验证购买积分
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

    <RedeemRevenueTable :data="redeemRevenue" :loading="loading" :show-title="false" />
  </div>
</template>

<style scoped lang="scss">
.analytics-filter {
  margin-bottom: 16px;
}

.revenue-purchase-entry {
  height: 42px;
}

@media (max-width: 768px) {
  .warm-page-header {
    gap: 12px;
  }

  .revenue-purchase-entry {
    width: 100%;
  }

  .analytics-filter-row {
    align-items: stretch;
  }

  .analytics-filter-date,
  .analytics-action-btn {
    width: 100%;
  }

  .analytics-segmented-group {
    width: 100%;
  }

  .analytics-segmented-group :deep(.ant-radio-button-wrapper) {
    flex: 1;
    text-align: center;
  }
}
</style>
