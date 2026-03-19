<script setup lang="ts">
import { ref, onMounted } from "vue";
import { message } from "ant-design-vue";
import {
  BarChartOutlined,
  ThunderboltOutlined,
  CalendarOutlined,
  TeamOutlined,
  UserOutlined,
} from "@ant-design/icons-vue";
import { getStats, getAdminHistory } from "@/api/admin";
import type { AdminStats, HistoryItem } from "@/types";

const stats = ref<AdminStats>({ last_7_days: 0, last_30_days: 0, total_users: 0, active_users: 0 });
const history = ref<HistoryItem[]>([]);
const historyTotal = ref(0);
const page = ref(1);
const loading = ref(false);

const columns = [
  { title: "ID", dataIndex: "task_id", width: 70 },
  { title: "风格", dataIndex: "style_name", width: 120 },
  { title: "模型", dataIndex: "model", width: 110 },
  { title: "尺寸", dataIndex: "size", width: 110 },
  { title: "状态", dataIndex: "status", width: 90 },
  { title: "图片", key: "imgCount", width: 70 },
  { title: "时间", dataIndex: "created_at" },
];

async function loadStats() {
  try { stats.value = await getStats(); }
  catch { message.error("获取统计失败"); }
}

async function loadHistory() {
  loading.value = true;
  try {
    const res = await getAdminHistory(page.value, 10);
    history.value = res.items;
    historyTotal.value = res.total;
  } catch { message.error("获取记录失败"); }
  finally { loading.value = false; }
}

onMounted(() => { loadStats(); loadHistory(); });

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

const statCards = [
  { key: "last_7_days", label: "近 7 天生成", icon: ThunderboltOutlined, color: "#1890ff" },
  { key: "last_30_days", label: "近 30 天生成", icon: CalendarOutlined, color: "#722ed1" },
  { key: "total_users", label: "总用户数", icon: TeamOutlined, color: "#13c2c2" },
  { key: "active_users", label: "活跃用户", icon: UserOutlined, color: "#52c41a" },
];
</script>

<template>
  <div>
    <div class="page-header">
      <h2 class="page-title">
        <BarChartOutlined style="margin-right: 8px" />
        数据统计
      </h2>
    </div>

    <div class="stats-grid">
      <div v-for="sc in statCards" :key="sc.key" class="stat-card dashboard-card">
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

    <div class="dashboard-card" style="padding: 0; overflow: hidden">
      <a-table
        :columns="columns"
        :data-source="history"
        :loading="loading"
        row-key="task_id"
        :pagination="false"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.dataIndex === 'status'">
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

    <div v-if="historyTotal > 10" class="pagination">
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
.page-header {
  margin-bottom: 24px;
}

.page-title {
  font-size: 20px;
  font-weight: 700;
  color: var(--text);
}

.section-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text);
  margin: 32px 0 16px;
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
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stat-val {
  font-size: 28px;
  font-weight: 700;
  color: var(--text);
  line-height: 1.2;
}

.stat-lbl {
  font-size: 13px;
  color: var(--text-secondary);
  margin-top: 2px;
}

.pagination {
  display: flex;
  justify-content: center;
  margin-top: 28px;
}

@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
