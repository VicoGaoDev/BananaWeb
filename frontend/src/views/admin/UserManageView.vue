<script setup lang="ts">
import { ref, onMounted, reactive, computed } from "vue";
import { message, Modal } from "ant-design-vue";
import { PlusOutlined, TeamOutlined, WalletOutlined } from "@ant-design/icons-vue";
import { listUsers, createUser, updateUserStatus, updateUserRole, resetUserPassword, allocateCredits } from "@/api/admin";
import { useAuthStore } from "@/stores/auth";
import type { AdminUser } from "@/types";

const auth = useAuthStore();
const isSuperAdmin = computed(() => auth.isSuperAdmin);

const users = ref<AdminUser[]>([]);
const loading = ref(false);
const modalOpen = ref(false);
const creating = ref(false);
const form = reactive({ username: "", password: "", role: "user" });

const resetPwdOpen = ref(false);
const resetPwdLoading = ref(false);
const resetTarget = ref<AdminUser | null>(null);
const resetForm = reactive({ newPassword: "" });

const creditsOpen = ref(false);
const creditsLoading = ref(false);
const creditsTarget = ref<AdminUser | null>(null);
const creditsForm = reactive({ amount: 0, description: "" });

const columns = [
  { title: "ID", dataIndex: "id", width: 70 },
  { title: "用户", dataIndex: "username", width: 200 },
  { title: "角色", dataIndex: "role", width: 100 },
  { title: "积分", dataIndex: "credits", width: 100 },
  { title: "状态", dataIndex: "status", width: 90 },
  { title: "创建时间", dataIndex: "created_at", width: 170 },
  { title: "操作", key: "action", width: 320 },
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
  creditsLoading.value = true;
  try {
    await allocateCredits(creditsTarget.value.id, creditsForm.amount, creditsForm.description);
    message.success("积分分配成功");
    creditsOpen.value = false;
    load();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "分配失败");
  } finally {
    creditsLoading.value = false;
  }
}

function isFirstAdmin(u: AdminUser) {
  const admins = users.value.filter((x) => x.role === "admin");
  if (!admins.length) return false;
  admins.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
  return admins[0].id === u.id;
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
          <div class="warm-page-desc">超级管理员可管理账号权限，普通管理员仅可分配积分。</div>
        </div>
      </div>
      <a-button v-if="isSuperAdmin" type="primary" class="warm-primary-btn" @click="modalOpen = true">
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
          <a-input v-model:value="creditsForm.description" placeholder="可选" />
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
