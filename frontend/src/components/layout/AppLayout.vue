<script setup lang="ts">
import { ref, computed, h } from "vue";
import { useRouter, useRoute } from "vue-router";
import { useAuthStore } from "@/stores/auth";
import { message } from "ant-design-vue";
import { changePassword } from "@/api/auth";
import {
  PictureOutlined,
  HistoryOutlined,
  SettingOutlined,
  UserOutlined,
  TeamOutlined,
  BgColorsOutlined,
  BarChartOutlined,
  KeyOutlined,
  LogoutOutlined,
  LockOutlined,
  DownOutlined,
} from "@ant-design/icons-vue";

const router = useRouter();
const route = useRoute();
const auth = useAuthStore();
const isAdmin = computed(() => auth.isAdmin);

const selectedKeys = computed(() => {
  const p = route.path;
  if (p.startsWith("/admin")) return ["admin"];
  if (p === "/history") return ["history"];
  return ["generate"];
});

function handleMenuClick({ key }: { key: string }) {
  if (key === "generate") router.push("/generate");
  else if (key === "history") router.push("/history");
}

function handleAdminMenu({ key }: { key: string }) {
  router.push(key);
}

function handleUserMenu({ key }: { key: string }) {
  if (key === "password") pwdVisible.value = true;
  else if (key === "logout") {
    auth.logout();
    router.push("/login");
  }
}

const pwdVisible = ref(false);
const pwdForm = ref({ oldPassword: "", newPassword: "", confirmPassword: "" });
const pwdLoading = ref(false);

async function handleChangePwd() {
  if (!pwdForm.value.oldPassword || !pwdForm.value.newPassword) {
    message.warning("请填写完整");
    return;
  }
  if (pwdForm.value.newPassword !== pwdForm.value.confirmPassword) {
    message.warning("两次密码不一致");
    return;
  }
  pwdLoading.value = true;
  try {
    await changePassword(pwdForm.value.oldPassword, pwdForm.value.newPassword);
    message.success("密码修改成功");
    pwdVisible.value = false;
    pwdForm.value = { oldPassword: "", newPassword: "", confirmPassword: "" };
  } catch (err: any) {
    message.error(err.response?.data?.detail || "修改失败");
  } finally {
    pwdLoading.value = false;
  }
}
</script>

<template>
  <a-layout class="app-layout">
    <a-layout-header class="app-header">
      <div class="header-inner">
        <div class="header-brand" @click="router.push('/generate')">
          <span class="brand-emoji">🍌</span>
          <span class="brand-name">Banana Web</span>
        </div>

        <a-menu
          mode="horizontal"
          :selected-keys="selectedKeys"
          class="header-menu"
          @click="handleMenuClick"
        >
          <a-menu-item key="generate">
            <PictureOutlined />
            <span>绘图</span>
          </a-menu-item>
          <a-menu-item key="history">
            <HistoryOutlined />
            <span>历史记录</span>
          </a-menu-item>
        </a-menu>

        <div class="header-actions">
          <a-dropdown v-if="isAdmin" :trigger="['click']">
            <a-button class="admin-btn" type="text">
              <SettingOutlined />
              管理后台
              <DownOutlined style="font-size: 10px; margin-left: 4px" />
            </a-button>
            <template #overlay>
              <a-menu @click="handleAdminMenu">
                <a-menu-item key="/admin/users">
                  <TeamOutlined />
                  <span style="margin-left: 8px">用户管理</span>
                </a-menu-item>
                <a-menu-item key="/admin/styles">
                  <BgColorsOutlined />
                  <span style="margin-left: 8px">风格管理</span>
                </a-menu-item>
                <a-menu-item key="/admin/dashboard">
                  <BarChartOutlined />
                  <span style="margin-left: 8px">数据统计</span>
                </a-menu-item>
                <a-menu-item key="/admin/api-key">
                  <KeyOutlined />
                  <span style="margin-left: 8px">API Key</span>
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>

          <a-dropdown :trigger="['click']">
            <div class="user-trigger">
              <a-avatar :size="32" class="user-avatar">
                {{ auth.user?.username?.charAt(0)?.toUpperCase() }}
              </a-avatar>
              <span class="user-name">{{ auth.user?.username }}</span>
            </div>
            <template #overlay>
              <a-menu @click="handleUserMenu">
                <a-menu-item key="password">
                  <LockOutlined />
                  <span style="margin-left: 8px">修改密码</span>
                </a-menu-item>
                <a-menu-divider />
                <a-menu-item key="logout" danger>
                  <LogoutOutlined />
                  <span style="margin-left: 8px">退出登录</span>
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
        </div>
      </div>
    </a-layout-header>

    <a-layout-content class="app-content">
      <div class="content-inner">
        <router-view />
      </div>
    </a-layout-content>

    <!-- Change Password Modal -->
    <a-modal
      v-model:open="pwdVisible"
      title="修改密码"
      :confirm-loading="pwdLoading"
      @ok="handleChangePwd"
      ok-text="确认修改"
      cancel-text="取消"
      :width="420"
      centered
    >
      <a-form layout="vertical" style="margin-top: 16px">
        <a-form-item label="原密码">
          <a-input-password v-model:value="pwdForm.oldPassword" placeholder="请输入原密码" />
        </a-form-item>
        <a-form-item label="新密码">
          <a-input-password v-model:value="pwdForm.newPassword" placeholder="至少6位" />
        </a-form-item>
        <a-form-item label="确认新密码" style="margin-bottom: 0">
          <a-input-password v-model:value="pwdForm.confirmPassword" placeholder="请再次输入" />
        </a-form-item>
      </a-form>
    </a-modal>
  </a-layout>
</template>

<style scoped lang="scss">
.app-layout {
  min-height: 100vh;
  background: var(--bg);
}

.app-header {
  background: #fff !important;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  padding: 0 !important;
  height: 64px;
  line-height: 64px;
  position: sticky;
  top: 0;
  z-index: 100;
}

.header-inner {
  max-width: 1400px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  padding: 0 32px;
  height: 64px;
}

.header-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  margin-right: 40px;
  flex-shrink: 0;
}

.brand-emoji {
  font-size: 28px;
}

.brand-name {
  font-size: 18px;
  font-weight: 700;
  color: var(--text);
  letter-spacing: -0.3px;
}

.header-menu {
  flex: 1;
  border-bottom: none !important;
  background: transparent;
  line-height: 62px;

  :deep(.ant-menu-item) {
    font-weight: 500;

    &::after {
      border-bottom-width: 2px !important;
    }
  }
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
  flex-shrink: 0;
}

.admin-btn {
  font-weight: 500;
  color: var(--text-secondary) !important;

  &:hover {
    color: var(--primary) !important;
  }
}

.user-trigger {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 4px 12px;
  border-radius: 20px;
  cursor: pointer;
  transition: background 0.2s;

  &:hover {
    background: #f5f5f5;
  }
}

.user-avatar {
  background: linear-gradient(135deg, #1890ff, #096dd9);
  font-weight: 600;
}

.user-name {
  font-size: 14px;
  font-weight: 500;
  color: var(--text);
}

.app-content {
  padding: 24px;
}

.content-inner {
  max-width: 1400px;
  margin: 0 auto;
}
</style>
