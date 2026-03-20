<script setup lang="ts">
import { ref, onMounted, reactive } from "vue";
import { message, Modal } from "ant-design-vue";
import { PlusOutlined, TeamOutlined } from "@ant-design/icons-vue";
import { listUsers, createUser, updateUserStatus, updateUserRole } from "@/api/admin";
import type { AdminUser } from "@/types";

const users = ref<AdminUser[]>([]);
const loading = ref(false);
const modalOpen = ref(false);
const creating = ref(false);
const form = reactive({ username: "", password: "", role: "user" });

const columns = [
  { title: "ID", dataIndex: "id", width: 70 },
  { title: "用户", dataIndex: "username", width: 220 },
  { title: "角色", dataIndex: "role", width: 120 },
  { title: "状态", dataIndex: "status", width: 100 },
  { title: "创建时间", dataIndex: "created_at", width: 180 },
  { title: "操作", key: "action", width: 220 },
];

async function load() {
  loading.value = true;
  try { users.value = await listUsers(); }
  catch { message.error("获取用户列表失败"); }
  finally { loading.value = false; }
}
onMounted(load);

async function handleCreate() {
  if (!form.username || !form.password) { message.warning("请填写完整"); return; }
  creating.value = true;
  try {
    await createUser({ username: form.username, password: form.password, role: form.role });
    message.success("创建成功");
    modalOpen.value = false;
    form.username = ""; form.password = ""; form.role = "user";
    load();
  } catch (err: any) { message.error(err.response?.data?.detail || "创建失败"); }
  finally { creating.value = false; }
}

function toggleStatus(u: AdminUser) {
  const next = u.status === "active" ? "disabled" : "active";
  const label = next === "disabled" ? "禁用" : "启用";
  Modal.confirm({
    title: `确认${label}用户 "${u.username}" ？`,
    centered: true,
    async onOk() {
      await updateUserStatus(u.id, next);
      message.success(`${label}成功`);
      load();
    },
  });
}

function toggleRole(u: AdminUser) {
  const next = u.role === "admin" ? "user" : "admin";
  const label = next === "admin" ? "设为管理员" : "取消管理员";
  Modal.confirm({
    title: `确认${label} "${u.username}" ？`,
    centered: true,
    async onOk() {
      await updateUserRole(u.id, next);
      message.success(`${label}成功`);
      load();
    },
  });
}

function fmtTime(t: string) { return t ? new Date(t).toLocaleString("zh-CN") : "-"; }
</script>

<template>
  <div class="warm-page">
    <div class="warm-page-header">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <TeamOutlined />
        </div>
        <div>
          <div class="warm-page-title">用户管理</div>
          <div class="warm-page-desc">统一管理账号、角色权限与启用状态。</div>
        </div>
      </div>
      <a-button type="primary" class="warm-primary-btn" @click="modalOpen = true">
        <template #icon><PlusOutlined /></template>
        新增用户
      </a-button>
    </div>

    <div class="warm-card warm-table-card">
      <a-table
        :columns="columns"
        :data-source="users"
        :loading="loading"
        row-key="id"
        :pagination="false"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.dataIndex === 'username'">
            <div class="user-cell">
              <a-avatar :size="34" :src="record.avatar_url || undefined" class="table-avatar">
                {{ record.username?.charAt(0)?.toUpperCase() }}
              </a-avatar>
              <span class="user-cell-name">{{ record.username }}</span>
            </div>
          </template>
          <template v-else-if="column.dataIndex === 'role'">
            <a-tag class="warm-tag" :color="record.role === 'admin' ? 'volcano' : 'gold'">
              {{ record.role === "admin" ? "管理员" : "普通用户" }}
            </a-tag>
          </template>
          <template v-else-if="column.dataIndex === 'status'">
            <a-badge :status="record.status === 'active' ? 'success' : 'error'" />
            {{ record.status === "active" ? "正常" : "禁用" }}
          </template>
          <template v-else-if="column.dataIndex === 'created_at'">
            {{ fmtTime(record.created_at) }}
          </template>
          <template v-else-if="column.key === 'action'">
            <a-button
              type="link"
              size="small"
              :danger="record.status === 'active'"
              @click="toggleStatus(record)"
            >
              {{ record.status === "active" ? "禁用" : "启用" }}
            </a-button>
            <a-divider type="vertical" />
            <a-button type="link" size="small" @click="toggleRole(record)">
              {{ record.role === "admin" ? "取消管理员" : "设为管理员" }}
            </a-button>
          </template>
        </template>
      </a-table>
    </div>

    <!-- Create user modal -->
    <a-modal
      v-model:open="modalOpen"
      title="新增用户"
      :confirm-loading="creating"
      ok-text="创建"
      cancel-text="取消"
      centered
      :width="440"
      @ok="handleCreate"
    >
      <a-form layout="vertical" style="margin-top: 16px">
        <a-form-item label="用户名">
          <a-input v-model:value="form.username" placeholder="请输入用户名" />
        </a-form-item>
        <a-form-item label="密码">
          <a-input-password v-model:value="form.password" placeholder="至少6位" />
        </a-form-item>
        <a-form-item label="角色" style="margin-bottom: 0">
          <a-radio-group v-model:value="form.role">
            <a-radio value="user">普通用户</a-radio>
            <a-radio value="admin">管理员</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<style scoped lang="scss">
.user-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.table-avatar {
  background: linear-gradient(180deg, #ffd06d, #ffb02b);
  color: #5a3c14;
  font-weight: 700;
}

.user-cell-name {
  color: #4c341a;
  font-weight: 700;
}

:deep(.ant-badge-status-text) {
  color: #6b5436;
  font-weight: 600;
}
</style>
