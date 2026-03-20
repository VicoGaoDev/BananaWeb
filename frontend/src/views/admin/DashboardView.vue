<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { message } from "ant-design-vue";
import type { Dayjs } from "dayjs";
import {
  BarChartOutlined,
  ThunderboltOutlined,
  CalendarOutlined,
  TeamOutlined,
  UserOutlined,
  SearchOutlined,
  UndoOutlined,
} from "@ant-design/icons-vue";
import { getStats, getAdminHistory, listUsers } from "@/api/admin";
import type { AdminStats, AdminUser, HistoryItem, HistoryFilter } from "@/types";

const stats = ref<AdminStats>({ last_7_days: 0, last_30_days: 0, total_users: 0, active_users: 0 });
const history = ref<HistoryItem[]>([]);
const historyTotal = ref(0);
const page = ref(1);
const loading = ref(false);
const users = ref<AdminUser[]>([]);

const filter = reactive<{
  status: string | undefined;
  user_id: number | undefined;
  dateRange: [Dayjs, Dayjs] | null;
}>({
  status: undefined,
  user_id: undefined,
  dateRange: null,
});

const columns = [
  { title: "ID", dataIndex: "task_id", width: 70 },
  { title: "用户", dataIndex: "username", width: 160 },
  { title: "风格", dataIndex: "style_name", width: 120 },
  { title: "尺寸", dataIndex: "size", width: 100 },
  { title: "状态", dataIndex: "status", width: 90 },
  { title: "图片", key: "imgCount", width: 70 },
  { title: "时间", dataIndex: "created_at" },
];

function buildFilter(): HistoryFilter | undefined {
  const f: HistoryFilter = {};
  if (filter.status) f.status = filter.status;
  if (filter.user_id) f.user_id = filter.user_id;
  if (filter.dateRange) {
    f.start_date = filter.dateRange[0].startOf("day").toISOString();
    f.end_date = filter.dateRange[1].endOf("day").toISOString();
  }
  return Object.keys(f).length ? f : undefined;
}

async function loadStats() {
  try { stats.value = await getStats(); }
  catch { message.error("获取统计失败"); }
}

async function loadUsers() {
  try { users.value = await listUsers(); }
  catch { /* ignore */ }
}

async function loadHistory() {
  loading.value = true;
  try {
    const res = await getAdminHistory(page.value, 10, buildFilter());
    history.value = res.items;
    historyTotal.value = res.total;
  } catch { message.error("获取记录失败"); }
  finally { loading.value = false; }
}

function handleSearch() {
  page.value = 1;
  loadHistory();
}

function handleReset() {
  filter.status = undefined;
  filter.user_id = undefined;
  filter.dateRange = null;
  page.value = 1;
  loadHistory();
}

onMounted(() => { loadStats(); loadUsers(); loadHistory(); });

function handlePageChange(p: number) { page.value = p; loadHistory(); }
function fmtTime(t: string) { return t ? new Date(t).toLocaleString("zh-CN") : "-"; }
function statusLabel(s: string) {
  const m: Record<string, string> = { success: "成功", failed: "失败", processing: "处理中", pending: "等待中" };
  return m[s] || s;
}
function statusColor(s: string) {
  if (s === "success") return "green";
  if (s === "failed") return "red";
  if (s === "processing") return "orange";
  return "default";
}

const statusOptions = [
  { value: "pending", label: "等待中" },
  { value: "processing", label: "处理中" },
  { value: "success", label: "成功" },
  { value: "failed", label: "失败" },
];

const statCards = [
  { key: "last_7_days", label: "近 7 天生成", icon: ThunderboltOutlined, color: "#1890ff" },
  { key: "last_30_days", label: "近 30 天生成", icon: CalendarOutlined, color: "#722ed1" },
  { key: "total_users", label: "总用户数", icon: TeamOutlined, color: "#13c2c2" },
  { key: "active_users", label: "活跃用户", icon: UserOutlined, color: "#52c41a" },
];
</script>

<template>
  <div class="warm-page">
    <div class="warm-page-header">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <BarChartOutlined />
        </div>
        <div>
          <div class="warm-page-title">数据统计</div>
          <div class="warm-page-desc">查看用户活跃情况、生成任务趋势与全站记录。</div>
        </div>
      </div>
    </div>

    <div class="stats-grid">
      <div v-for="sc in statCards" :key="sc.key" class="stat-card warm-card">
        <div class="stat-icon" :style="{ background: sc.color + '15', color: sc.color }">
          <component :is="sc.icon" style="font-size: 24px" />
        </div>
        <div class="stat-body">
          <div class="stat-val">{{ (stats as any)[sc.key] }}</div>
          <div class="stat-lbl">{{ sc.label }}</div>
        </div>
      </div>
    </div>

    <h3 class="section-title">全部生成记录</h3>

    <div class="filter-bar warm-card">
      <a-select
        v-model:value="filter.status"
        placeholder="状态"
        allow-clear
        :options="statusOptions"
        class="filter-select"
      />
      <a-select
        v-model:value="filter.user_id"
        placeholder="用户"
        allow-clear
        show-search
        option-filter-prop="label"
        class="filter-select"
      >
        <a-select-option
          v-for="u in users"
          :key="u.id"
          :value="u.id"
          :label="u.username"
        >
          {{ u.username }}
        </a-select-option>
      </a-select>
      <a-range-picker
        v-model:value="filter.dateRange"
        class="filter-date"
      />
      <a-button type="primary" class="warm-primary-btn filter-btn" @click="handleSearch">
        <template #icon><SearchOutlined /></template>查询
      </a-button>
      <a-button class="filter-btn filter-reset" @click="handleReset">
        <template #icon><UndoOutlined /></template>重置
      </a-button>
    </div>

    <div class="warm-card warm-table-card">
      <a-table
        :columns="columns"
        :data-source="history"
        :loading="loading"
        row-key="task_id"
        :pagination="false"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.dataIndex === 'username'">
            <div class="table-user-cell">
              <a-avatar :size="30" :src="record.avatar_url || undefined" class="table-user-avatar">
                {{ record.username?.charAt(0)?.toUpperCase() }}
              </a-avatar>
              <span>{{ record.username || "-" }}</span>
            </div>
          </template>
          <template v-else-if="column.dataIndex === 'status'">
            <a-tag :color="statusColor(record.status)">{{ statusLabel(record.status) }}</a-tag>
          </template>
          <template v-else-if="column.key === 'imgCount'">
            {{ record.images.length }}
          </template>
          <template v-else-if="column.dataIndex === 'created_at'">
            {{ fmtTime(record.created_at) }}
          </template>
        </template>
      </a-table>
    </div>

    <div v-if="historyTotal > 10" class="warm-pagination">
      <a-pagination
        :current="page"
        :total="historyTotal"
        :page-size="10"
        show-less-items
        @change="handlePageChange"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.section-title {
  font-size: 16px;
  font-weight: 700;
  color: #5d4526;
  margin: 6px 0 -2px;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 24px;
}

.stat-icon {
  width: 52px;
  height: 52px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stat-val {
  font-size: 28px;
  font-weight: 700;
  color: #4c341a;
  line-height: 1.2;
}

.stat-lbl {
  font-size: 13px;
  color: #8c7458;
  margin-top: 2px;
}

.filter-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px 20px;
  margin-bottom: 0;
  flex-wrap: wrap;
}

.filter-select {
  width: 140px;
}

.filter-date {
  width: 260px;
}

.filter-btn {
  height: 36px;
  border-radius: 12px;
  font-weight: 600;
  padding-inline: 16px;
}

.filter-reset {
  border: 1px solid #e8d5c0 !important;
  background: linear-gradient(180deg, #fffaf5, #fef3e8) !important;
  color: #8c7458 !important;

  &:hover {
    border-color: #d4b896 !important;
    color: #5d4526 !important;
  }
}

.table-user-cell {
  display: flex;
  align-items: center;
  gap: 10px;
  color: #4c341a;
  font-weight: 700;
}

.table-user-avatar {
  background: linear-gradient(180deg, #ffd06d, #ffb02b);
  color: #5a3c14;
  font-weight: 700;
}

@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-select,
  .filter-date {
    width: 100%;
  }
}
</style>
