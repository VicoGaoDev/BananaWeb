<script setup lang="ts">
import { ref, onMounted, reactive, computed } from "vue";
import { message, Modal } from "ant-design-vue";
import { PlusOutlined, TeamOutlined, WalletOutlined, SearchOutlined, UndoOutlined } from "@ant-design/icons-vue";
import {
  listUsers,
  createUser,
  updateUserStatus,
  updateUserRole,
  updateUserWhitelist,
  resetUserPassword,
  allocateCredits,
} from "@/api/admin";
import { useAuthStore } from "@/stores/auth";
import type { AdminUser } from "@/types";

const auth = useAuthStore();
const isSuperAdmin = computed(() => auth.isSuperAdmin);

const users = ref<AdminUser[]>([]);
const loading = ref(false);
const modalOpen = ref(false);
const creating = ref(false);
const form = reactive({ username: "", password: "", role: "user" });
const filters = reactive({
  username: "",
  status: undefined as "active" | "disabled" | undefined,
  sort: "created_at_desc" as "created_at_desc" | "credits_desc",
});

const resetPwdOpen = ref(false);
const resetPwdLoading = ref(false);
const resetTarget = ref<AdminUser | null>(null);
const resetForm = reactive({ newPassword: "" });

const creditsOpen = ref(false);
const creditsLoading = ref(false);
const creditsTarget = ref<AdminUser | null>(null);
const creditsForm = reactive({ amount: 0, description: "" });
const whitelistOpen = ref(false);
const whitelistKeyword = ref("");
const whitelistLoadingId = ref<number | null>(null);

const columns = [
  { title: "ID", dataIndex: "id", width: 70 },
  { title: "用户", dataIndex: "username", width: 200 },
  { title: "角色", dataIndex: "role", width: 100 },
  { title: "白名单", dataIndex: "is_whitelisted", width: 100 },
  { title: "积分", dataIndex: "credits", width: 100 },
  { title: "状态", dataIndex: "status", width: 90 },
  { title: "创建时间", dataIndex: "created_at", width: 170 },
  { title: "操作", key: "action", width: 320 },
];

const filteredUsers = computed(() => {
  const keyword = filters.username.trim().toLowerCase();
  const list = users.value.filter((user) => {
    const matchUsername = !keyword || user.username.toLowerCase().includes(keyword);
    const matchStatus = !filters.status || user.status === filters.status;
    return matchUsername && matchStatus;
  });

  return [...list].sort((a, b) => {
    if (filters.sort === "credits_desc") {
      if (b.credits !== a.credits) return b.credits - a.credits;
      return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    }
    return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
  });
});

const filteredWhitelistUsers = computed(() => {
  const keyword = whitelistKeyword.value.trim().toLowerCase();
  return [...users.value]
    .filter((user) => !keyword || user.username.toLowerCase().includes(keyword))
    .sort((a, b) => {
      if (a.is_whitelisted !== b.is_whitelisted) return a.is_whitelisted ? -1 : 1;
      return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    });
});

const whitelistedCount = computed(() => users.value.filter((user) => user.is_whitelisted).length);

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

function openResetPwd(u: AdminUser) {
  resetTarget.value = u;
  resetForm.newPassword = "";
  resetPwdOpen.value = true;
}

async function handleResetPwd() {
  if (!resetTarget.value) return;
  if (!resetForm.newPassword || resetForm.newPassword.length < 6) {
    message.warning("新密码至少6位");
    return;
  }
  resetPwdLoading.value = true;
  try {
    await resetUserPassword(resetTarget.value.id, resetForm.newPassword);
    message.success(`已重置 "${resetTarget.value.username}" 的密码`);
    resetPwdOpen.value = false;
  } catch (err: any) {
    message.error(err.response?.data?.detail || "重置失败");
  } finally {
    resetPwdLoading.value = false;
  }
}

function openCredits(u: AdminUser) {
  creditsTarget.value = u;
  creditsForm.amount = 0;
  creditsForm.description = "";
  creditsOpen.value = true;
}

async function handleAllocateCredits() {
  if (!creditsTarget.value || creditsForm.amount === 0) {
    message.warning("请输入有效的积分数量");
    return;
  }
  if (!creditsForm.description.trim()) {
    message.warning("请填写备注说明");
    return;
  }
  creditsLoading.value = true;
  try {
    await allocateCredits(creditsTarget.value.id, creditsForm.amount, creditsForm.description.trim());
    message.success("积分分配成功");
    creditsOpen.value = false;
    load();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "分配失败");
  } finally {
    creditsLoading.value = false;
  }
}

async function handleToggleWhitelist(user: AdminUser) {
  whitelistLoadingId.value = user.id;
  const next = !user.is_whitelisted;
  try {
    await updateUserWhitelist(user.id, next);
    message.success(next ? "已加入白名单" : "已移出白名单");
    await load();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "白名单更新失败");
  } finally {
    whitelistLoadingId.value = null;
  }
}

function isFirstAdmin(u: AdminUser) {
  const admins = users.value.filter((x) => x.role === "admin");
  if (!admins.length) return false;
  admins.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
  return admins[0].id === u.id;
}

function resetFilters() {
  filters.username = "";
  filters.status = undefined;
  filters.sort = "created_at_desc";
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
          <div class="warm-page-desc">管理员可创建普通用户、管理白名单与分配积分，超级管理员可额外管理权限。</div>
        </div>
      </div>
      <div class="header-actions">
        <a-button class="filter-reset-btn" @click="whitelistOpen = true">
          白名单用户
        </a-button>
        <a-button type="primary" class="warm-primary-btn" @click="modalOpen = true">
          <template #icon><PlusOutlined /></template>
          新增用户
        </a-button>
      </div>
    </div>

    <div class="warm-card filter-bar">
      <a-input
        v-model:value="filters.username"
        allow-clear
        placeholder="按用户名筛选"
        class="filter-input"
      >
        <template #prefix><SearchOutlined /></template>
      </a-input>
      <a-select
        v-model:value="filters.status"
        allow-clear
        placeholder="用户状态"
        class="filter-select"
      >
        <a-select-option value="active">正常</a-select-option>
        <a-select-option value="disabled">禁用</a-select-option>
      </a-select>
      <a-select
        v-model:value="filters.sort"
        class="filter-select"
      >
        <a-select-option value="created_at_desc">创建时间（默认）</a-select-option>
        <a-select-option value="credits_desc">剩余积分（从高到低）</a-select-option>
      </a-select>
      <a-button class="filter-reset-btn" @click="resetFilters">
        <template #icon><UndoOutlined /></template>
        重置
      </a-button>
      <div class="filter-result-count">
        共筛出 <span>{{ filteredUsers.length }}</span> 个用户
      </div>
    </div>

    <div class="warm-card warm-table-card">
      <a-table
        :columns="columns"
        :data-source="filteredUsers"
        :loading="loading"
        row-key="id"
        :pagination="false"
        :scroll="{ x: 1050 }"
        class="admin-mobile-table"
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
          <template v-else-if="column.dataIndex === 'is_whitelisted'">
            <a-tag :color="record.is_whitelisted ? 'processing' : 'default'">
              {{ record.is_whitelisted ? "白名单" : "-" }}
            </a-tag>
          </template>
          <template v-else-if="column.dataIndex === 'credits'">
            <span style="font-weight: 700; color: #d48806">{{ record.credits }}</span>
          </template>
          <template v-else-if="column.dataIndex === 'status'">
            <a-badge :status="record.status === 'active' ? 'success' : 'error'" />
            {{ record.status === "active" ? "正常" : "禁用" }}
          </template>
          <template v-else-if="column.dataIndex === 'created_at'">
            {{ fmtTime(record.created_at) }}
          </template>
          <template v-else-if="column.key === 'action'">
            <div class="table-actions">
              <a-button type="link" size="small" @click="openCredits(record)">
                <template #icon><WalletOutlined /></template>
                分配积分
              </a-button>
              <template v-if="isSuperAdmin">
                <a-divider type="vertical" />
                <a-button
                  type="link"
                  size="small"
                  :danger="record.status === 'active'"
                  :disabled="isFirstAdmin(record) && record.status === 'active'"
                  @click="toggleStatus(record)"
                >
                  {{ record.status === "active" ? "禁用" : "启用" }}
                </a-button>
                <a-divider type="vertical" />
                <a-button
                  type="link"
                  size="small"
                  :disabled="isFirstAdmin(record)"
                  @click="toggleRole(record)"
                >
                  {{ record.role === "admin" ? "取消管理员" : "设为管理员" }}
                </a-button>
                <a-divider type="vertical" />
                <a-button type="link" size="small" @click="openResetPwd(record)">
                  重置密码
                </a-button>
              </template>
            </div>
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
        <a-form-item v-if="isSuperAdmin" label="角色" style="margin-bottom: 0">
          <a-radio-group v-model:value="form.role">
            <a-radio value="user">普通用户</a-radio>
            <a-radio value="admin">管理员</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item v-else label="角色" style="margin-bottom: 0">
          <a-input value="普通用户" disabled />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Reset password modal (superadmin only) -->
    <a-modal
      v-model:open="resetPwdOpen"
      :title="`重置密码 — ${resetTarget?.username}`"
      :confirm-loading="resetPwdLoading"
      ok-text="确认重置"
      cancel-text="取消"
      centered
      :width="440"
      @ok="handleResetPwd"
    >
      <a-form layout="vertical" style="margin-top: 16px">
        <a-form-item label="新密码" style="margin-bottom: 0">
          <a-input-password v-model:value="resetForm.newPassword" placeholder="至少6位" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Allocate credits modal -->
    <a-modal
      v-model:open="creditsOpen"
      :title="`分配积分 — ${creditsTarget?.username}`"
      :confirm-loading="creditsLoading"
      ok-text="确认"
      cancel-text="取消"
      centered
      :width="440"
      @ok="handleAllocateCredits"
    >
      <a-form layout="vertical" style="margin-top: 16px">
        <a-form-item label="积分数量（正数充值，负数扣减）">
          <a-input-number v-model:value="creditsForm.amount" style="width: 100%" placeholder="请输入积分数量" />
        </a-form-item>
        <a-form-item label="备注说明" style="margin-bottom: 0">
          <a-input v-model:value="creditsForm.description" placeholder="请输入备注说明" />
        </a-form-item>
      </a-form>
    </a-modal>

    <a-modal
      v-model:open="whitelistOpen"
      title="白名单用户"
      :footer="null"
      centered
      :width="720"
    >
      <div class="whitelist-dialog">
        <div class="whitelist-toolbar">
          <a-input
            v-model:value="whitelistKeyword"
            allow-clear
            placeholder="筛选用户名"
            class="whitelist-search"
          >
            <template #prefix><SearchOutlined /></template>
          </a-input>
          <div class="whitelist-summary">
            当前白名单 <span>{{ whitelistedCount }}</span> 人
          </div>
        </div>

        <div class="whitelist-list">
          <div v-for="user in filteredWhitelistUsers" :key="user.id" class="whitelist-item">
            <div class="user-cell">
              <a-avatar :size="36" :src="user.avatar_url || undefined" class="table-avatar">
                {{ user.username?.charAt(0)?.toUpperCase() }}
              </a-avatar>
              <div class="whitelist-user-meta">
                <div class="user-cell-name">
                  {{ user.username }}
                  <a-tag v-if="user.is_whitelisted" color="processing">白名单</a-tag>
                </div>
                <div class="whitelist-user-sub">
                  {{ user.role === "admin" ? "管理员" : "普通用户" }} · 积分 {{ user.credits }}
                </div>
              </div>
            </div>
            <a-button
              :type="user.is_whitelisted ? 'default' : 'primary'"
              :loading="whitelistLoadingId === user.id"
              class="whitelist-action-btn"
              @click="handleToggleWhitelist(user)"
            >
              {{ user.is_whitelisted ? "移出白名单" : "加入白名单" }}
            </a-button>
          </div>
        </div>
      </div>
    </a-modal>
  </div>
</template>

<style scoped lang="scss">
.header-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.filter-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px 20px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.filter-input {
  width: 220px;
}

.filter-select {
  width: 180px;
}

.filter-reset-btn {
  height: 36px;
  border-radius: 12px;
  border: 1px solid #e8d5c0 !important;
  background: linear-gradient(180deg, #fffaf5, #fef3e8) !important;
  color: #8c7458 !important;

  &:hover {
    border-color: #d4b896 !important;
    color: #5d4526 !important;
  }
}

.filter-result-count {
  margin-left: auto;
  color: #8c7458;
  font-size: 14px;
  white-space: nowrap;

  span {
    color: #b26c04;
    font-weight: 700;
  }
}

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

.table-actions {
  display: inline-flex;
  align-items: center;
  white-space: nowrap;
}

.whitelist-dialog {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin-top: 12px;
}

.whitelist-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

.whitelist-search {
  width: 240px;
}

.whitelist-summary {
  color: #8c7458;
  font-size: 14px;

  span {
    color: #b26c04;
    font-weight: 700;
  }
}

.whitelist-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  max-height: 420px;
  overflow: auto;
  padding-right: 4px;
}

.whitelist-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 12px 14px;
  border-radius: 14px;
  border: 1px solid rgba(240, 223, 190, 0.95);
  background: linear-gradient(180deg, rgba(255, 250, 240, 0.88), rgba(255, 255, 255, 0.82));
}

.whitelist-user-meta {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.whitelist-user-sub {
  color: #8c7458;
  font-size: 12px;
}

.whitelist-action-btn {
  flex-shrink: 0;
  min-width: 104px;
  border-radius: 12px;
}

:deep(.ant-badge-status-text) {
  color: #6b5436;
  font-weight: 600;
}

@media (max-width: 768px) {
  :deep(.admin-mobile-table .ant-table-content) {
    overflow-x: auto !important;
  }

  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-input,
  .filter-select {
    width: 100%;
  }

  .header-actions,
  .whitelist-toolbar,
  .whitelist-item {
    flex-direction: column;
    align-items: stretch;
  }

  .whitelist-search {
    width: 100%;
  }

  .filter-result-count {
    margin-left: 0;
  }
}
</style>
