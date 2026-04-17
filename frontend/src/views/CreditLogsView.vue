<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { message } from "ant-design-vue";
import {
  WalletOutlined,
  ArrowUpOutlined,
  ArrowDownOutlined,
  FilterOutlined,
} from "@ant-design/icons-vue";
import { useAuthStore } from "@/stores/auth";
import { getCreditLogs } from "@/api/auth";
import { listUsers } from "@/api/admin";
import type { CreditLog, AdminUser } from "@/types";
import dayjs from "dayjs";

const auth = useAuthStore();
const isAdmin = computed(() => auth.isAdmin);

const items = ref<CreditLog[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const loading = ref(false);

const filterUserId = ref<number | undefined>(undefined);
const filterDateRange = ref<[dayjs.Dayjs, dayjs.Dayjs] | null>(null);

const userList = ref<AdminUser[]>([]);

const columns = computed(() => {
  const base = [
    { title: "时间", dataIndex: "created_at", width: 180 },
    { title: "类型", dataIndex: "type", width: 100 },
    { title: "积分变动", dataIndex: "amount", width: 120 },
    { title: "说明", dataIndex: "description", ellipsis: true },
    { title: "操作人", dataIndex: "operator_name", width: 120 },
  ];
  if (isAdmin.value) {
    base.splice(1, 0, { title: "用户", dataIndex: "username", width: 120 });
  }
  return base;
});

async function loadLogs() {
  loading.value = true;
  try {
    const params: Record<string, unknown> = {
      page: page.value,
      page_size: pageSize.value,
    };
    if (isAdmin.value && filterUserId.value) {
      params.user_id = filterUserId.value;
    }
    if (filterDateRange.value) {
      params.start_date = filterDateRange.value[0].startOf("day").toISOString();
      params.end_date = filterDateRange.value[1].endOf("day").toISOString();
    }
    const res = await getCreditLogs(params as any);
    items.value = res.items;
    total.value = res.total;
  } catch {
    message.error("获取积分记录失败");
  } finally {
    loading.value = false;
  }
}

async function loadUsers() {
  if (!isAdmin.value) return;
  try {
    userList.value = await listUsers();
  } catch {
    /* ignore */
  }
}

function handlePageChange(p: number) {
  page.value = p;
  loadLogs();
}

function handleFilter() {
  page.value = 1;
  loadLogs();
}

function handleReset() {
  filterUserId.value = undefined;
  filterDateRange.value = null;
  page.value = 1;
  loadLogs();
}

function formatTime(t: string) {
  return t ? dayjs(t).format("YYYY-MM-DD HH:mm:ss") : "-";
}

onMounted(() => {
  loadLogs();
  loadUsers();
});
</script>

<template>
  <div class="credit-logs-page">
    <div class="page-header">
      <WalletOutlined class="header-icon" />
      <h2>积分记录</h2>
      <div class="balance-badge" v-if="auth.user">
        余额: <strong>{{ auth.user.credits }}</strong> 积分
      </div>
    </div>

    <div class="filter-bar">
      <a-select
        v-if="isAdmin"
        v-model:value="filterUserId"
        placeholder="全部用户"
        allowClear
        show-search
        option-filter-prop="label"
        style="width: 180px"
      >
        <a-select-option
          v-for="u in userList"
          :key="u.id"
          :value="u.id"
          :label="u.username"
        >
          {{ u.username }}
        </a-select-option>
      </a-select>

      <a-range-picker
        v-model:value="filterDateRange"
        :placeholder="['开始日期', '结束日期']"
        style="width: 260px"
      />

      <a-button type="primary" class="credit-filter-btn credit-filter-btn-primary" @click="handleFilter">
        <template #icon><FilterOutlined /></template>
        筛选
      </a-button>
      <a-button class="credit-filter-btn credit-filter-btn-secondary" @click="handleReset">重置</a-button>
    </div>

    <a-table
      :columns="columns"
      :data-source="items"
      :loading="loading"
      :pagination="false"
      row-key="id"
      :scroll="{ x: 700 }"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'created_at'">
          {{ formatTime(record.created_at) }}
        </template>
        <template v-else-if="column.dataIndex === 'type'">
          <a-tag class="credit-type-tag" :class="record.type === 'allocate' ? 'credit-type-tag-income' : 'credit-type-tag-expense'">
            {{ record.type === "allocate" ? "充值" : "消耗" }}
          </a-tag>
        </template>
        <template v-else-if="column.dataIndex === 'amount'">
          <span :class="record.amount > 0 ? 'amount-plus' : 'amount-minus'">
            <ArrowUpOutlined v-if="record.amount > 0" />
            <ArrowDownOutlined v-else />
            {{ record.amount > 0 ? "+" : "" }}{{ record.amount }}
          </span>
        </template>
        <template v-else-if="column.dataIndex === 'operator_name'">
          {{ record.operator_name || "-" }}
        </template>
      </template>
    </a-table>

    <div class="pagination-wrap" v-if="total > pageSize">
      <a-pagination
        :current="page"
        :total="total"
        :page-size="pageSize"
        show-size-changer
        @change="handlePageChange"
      />
    </div>
  </div>
</template>

<style scoped>
.credit-logs-page {
  max-width: 960px;
  margin: 32px auto;
  padding: 0 24px;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 24px;
}

.page-header h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
}

.header-icon {
  font-size: 22px;
  color: #faad14;
}

.balance-badge {
  margin-left: auto;
  background: linear-gradient(135deg, #fff7e6, #fffbe6);
  border: 1px solid #ffe58f;
  border-radius: 8px;
  padding: 6px 16px;
  font-size: 14px;
  color: #d48806;
}

.balance-badge strong {
  font-size: 18px;
  margin: 0 2px;
}

.filter-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}

.credit-filter-btn {
  height: 36px;
  border-radius: 12px;
  font-weight: 600;
  box-shadow: none;
}

.credit-filter-btn-primary {
  border-color: #df8b1d !important;
  background: linear-gradient(135deg, #f2a533 0%, #df8b1d 100%) !important;
  color: #fff8eb !important;
}

.credit-filter-btn-primary:hover,
.credit-filter-btn-primary:focus {
  border-color: #c7770d !important;
  background: linear-gradient(135deg, #f5b24c 0%, #e49729 100%) !important;
  color: #ffffff !important;
}

.credit-filter-btn-secondary {
  border-color: #efc784 !important;
  background: #fff7e8 !important;
  color: #b16d10 !important;
}

.credit-filter-btn-secondary:hover,
.credit-filter-btn-secondary:focus {
  border-color: #e1a64a !important;
  background: #fff0d3 !important;
  color: #c7770d !important;
}

.credit-type-tag {
  border-radius: 999px;
  border-width: 1px;
  font-weight: 600;
}

.credit-type-tag-income {
  color: #c7770d;
  background: #fff4df;
  border-color: #efc784;
}

.credit-type-tag-expense {
  color: #a9772e;
  background: #fff8ee;
  border-color: #f2d8a7;
}

.amount-plus {
  color: #52c41a;
  font-weight: 600;
}

.amount-minus {
  color: #ff4d4f;
  font-weight: 600;
}

.pagination-wrap {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}

.pagination-wrap :deep(.ant-pagination-item) {
  border-radius: 10px;
  border-color: #f2d8a7;
}

.pagination-wrap :deep(.ant-pagination-item:hover) {
  border-color: #e1a64a;
}

.pagination-wrap :deep(.ant-pagination-item a) {
  color: #8f7558;
}

.pagination-wrap :deep(.ant-pagination-item-active) {
  border-color: #df8b1d;
  background: #fff4df;
}

.pagination-wrap :deep(.ant-pagination-item-active a) {
  color: #c7770d;
  font-weight: 600;
}

.pagination-wrap :deep(.ant-pagination-prev button),
.pagination-wrap :deep(.ant-pagination-next button) {
  border-radius: 10px;
  color: #8f7558;
}

.pagination-wrap :deep(.ant-pagination-options .ant-select-selector) {
  border-radius: 10px;
  border-color: #f2d8a7 !important;
}
</style>
