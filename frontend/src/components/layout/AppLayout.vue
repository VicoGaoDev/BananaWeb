<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useRouter, useRoute } from "vue-router";
import { useAuthStore } from "@/stores/auth";
import { message } from "ant-design-vue";
import { changePassword, getMe, uploadAvatar } from "@/api/auth";
import {
  PictureOutlined,
  HistoryOutlined,
  SettingOutlined,
  TeamOutlined,
  BgColorsOutlined,
  BarChartOutlined,
  KeyOutlined,
  LogoutOutlined,
  LockOutlined,
  UploadOutlined,
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

const adminSelectedKeys = computed(() => {
  if (!route.path.startsWith("/admin")) return [];
  return [route.path];
});

function handleMenuClick({ key }: { key: string }) {
  if (key === "generate") router.push("/generate");
  else if (key === "history") router.push("/history");
}

function handleAdminMenu({ key }: { key: string }) {
  router.push(key);
}

function handleUserMenu({ key }: { key: string }) {
  if (key === "avatar") avatarVisible.value = true;
  else if (key === "password") pwdVisible.value = true;
  else if (key === "logout") {
    auth.logout();
    router.push("/login");
  }
}

const pwdVisible = ref(false);
const pwdForm = ref({ oldPassword: "", newPassword: "", confirmPassword: "" });
const pwdLoading = ref(false);
const avatarVisible = ref(false);
const avatarUploading = ref(false);
const avatarInput = ref<HTMLInputElement | null>(null);

const avatarUrl = computed(() => auth.user?.avatar_url || "");
const avatarFallback = computed(() => auth.user?.username?.charAt(0)?.toUpperCase() || "U");

onMounted(async () => {
  if (!auth.isLoggedIn) return;
  try {
    auth.updateUser(await getMe());
  } catch {
    // ignore sync failures for stale sessions
  }
});

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

function triggerAvatarSelect() {
  avatarInput.value?.click();
}

async function handleAvatarChange(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;

  if (file.size > 1024 * 1024) {
    message.warning("头像图片不能超过 1MB");
    input.value = "";
    return;
  }

  if (!["image/jpeg", "image/png", "image/webp", "image/gif"].includes(file.type)) {
    message.warning("仅支持 JPG/PNG/WEBP/GIF 格式");
    input.value = "";
    return;
  }

  avatarUploading.value = true;
  try {
    const user = await uploadAvatar(file);
    auth.updateUser(user);
    avatarVisible.value = false;
    message.success("头像上传成功");
  } catch (err: any) {
    message.error(err.response?.data?.detail || "头像上传失败");
  } finally {
    avatarUploading.value = false;
    input.value = "";
  }
}
</script>

<template>
  <a-layout class="app-layout">
    <a-layout-header class="app-header">
      <div class="header-inner">
        <div class="header-brand" @click="router.push('/generate')">
          <div class="brand-mark">🍌</div>
          <div class="brand-copy">
            <span class="brand-name">Banana Web</span>
            <span class="brand-sub">AI Creative Studio</span>
          </div>
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
          <a-dropdown v-if="isAdmin" :trigger="['click']" overlay-class-name="warm-dropdown">
            <a-button class="admin-btn" type="text">
              <SettingOutlined />
              管理后台
              <DownOutlined style="font-size: 10px; margin-left: 4px" />
            </a-button>
            <template #overlay>
              <a-menu :selected-keys="adminSelectedKeys" @click="handleAdminMenu">
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

          <a-dropdown :trigger="['click']" overlay-class-name="warm-dropdown">
            <div class="user-trigger">
              <a-avatar :size="34" class="user-avatar" :src="avatarUrl || undefined">
                {{ avatarFallback }}
              </a-avatar>
              <span class="user-name">{{ auth.user?.username }}</span>
            </div>
            <template #overlay>
              <a-menu @click="handleUserMenu">
                <a-menu-item key="avatar">
                  <UploadOutlined />
                  <span style="margin-left: 8px">上传头像</span>
                </a-menu-item>
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

    <a-modal
      v-model:open="avatarVisible"
      title="上传头像"
      :footer="null"
      :width="420"
      centered
    >
      <div class="avatar-modal">
        <a-avatar :size="92" class="avatar-modal-preview" :src="avatarUrl || undefined">
          {{ avatarFallback }}
        </a-avatar>
        <div class="avatar-modal-text">支持 JPG / PNG / WEBP / GIF，图片最大 1MB</div>
        <input
          ref="avatarInput"
          type="file"
          accept="image/png,image/jpeg,image/webp,image/gif"
          hidden
          @change="handleAvatarChange"
        />
        <a-button
          type="primary"
          class="warm-primary-btn avatar-upload-btn"
          :loading="avatarUploading"
          @click="triggerAvatarSelect"
        >
          <template #icon><UploadOutlined /></template>
          {{ avatarUploading ? "上传中..." : "选择头像" }}
        </a-button>
      </div>
    </a-modal>

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
  background:
    radial-gradient(circle at top, rgba(255, 199, 103, 0.16), transparent 28%),
    linear-gradient(180deg, #fff8ee 0%, #fffdf9 100%);
}

.app-header {
  background: transparent !important;
  box-shadow: none;
  padding: 14px 20px 0 !important;
  height: 88px;
  line-height: normal;
  position: sticky;
  top: 0;
  z-index: 100;
}

.header-inner {
  max-width: 1400px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  padding: 0 28px;
  height: 74px;
  background: rgba(255, 252, 246, 0.88);
  border: 1px solid rgba(241, 210, 154, 0.7);
  border-radius: 26px;
  box-shadow: 0 16px 32px rgba(236, 185, 88, 0.12);
  backdrop-filter: blur(12px);
}

.header-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  margin-right: 34px;
  flex-shrink: 0;
}

.brand-mark {
  width: 44px;
  height: 44px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(180deg, #ffd06d, #ffaf29);
  box-shadow: 0 12px 22px rgba(255, 175, 41, 0.24);
  font-size: 24px;
}

.brand-copy {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.brand-name {
  font-size: 18px;
  font-weight: 700;
  color: #4c341a;
  letter-spacing: -0.2px;
}

.brand-sub {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #b8883f;
}

.header-menu {
  flex: 1;
  border-bottom: none !important;
  background: transparent;
  line-height: 54px;

  :deep(.ant-menu-item) {
    height: 46px;
    line-height: 46px;
    margin-inline: 4px !important;
    padding-inline: 16px !important;
    border-radius: 16px;
    font-weight: 700;
    color: #7c6644;

    &::after {
      display: none;
    }
  }

  :deep(.ant-menu-item-selected) {
    background: linear-gradient(180deg, #ffd06d, #ffb02b) !important;
    color: #523713 !important;
    box-shadow: 0 10px 18px rgba(255, 176, 43, 0.2);
  }

  :deep(.ant-menu-item:not(.ant-menu-item-selected):hover) {
    color: #d58b14 !important;
    background: rgba(255, 214, 140, 0.28) !important;
  }

  :deep(.ant-menu-title-content) {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-left: auto;
  flex-shrink: 0;
}

.admin-btn {
  height: 40px;
  padding-inline: 14px;
  border-radius: 999px;
  border: 1px solid #efcf93 !important;
  background: linear-gradient(180deg, #fff7e8, #ffefcf) !important;
  color: #b26c04 !important;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  box-shadow: 0 10px 22px rgba(239, 183, 73, 0.16);

  &:hover {
    color: #995b00 !important;
    border-color: #eab65d !important;
    background: linear-gradient(180deg, #fff2da, #ffe7b8) !important;
    box-shadow: 0 12px 24px rgba(239, 183, 73, 0.22);
  }
}

.user-trigger {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 8px 6px 6px;
  border-radius: 18px;
  cursor: pointer;
  transition: background 0.2s, border-color 0.2s;
  border: 1px solid transparent;

  &:hover {
    background: #fff8ec;
    border-color: #f1ddb7;
  }
}

.user-avatar {
  background: linear-gradient(180deg, #ffd06d, #ffb02b);
  color: #5a3c14;
  font-weight: 700;
  box-shadow: 0 10px 16px rgba(255, 176, 43, 0.2);
}

.user-name {
  font-size: 14px;
  font-weight: 700;
  color: #4c341a;
}

.app-content {
  padding: 22px 24px 28px;
}

.content-inner {
  max-width: 1400px;
  margin: 0 auto;
}

:deep(.warm-dropdown .ant-dropdown-menu) {
  padding: 10px;
  border-radius: 20px;
  border: 1px solid #f1ddb7;
  background: linear-gradient(180deg, #fffdf8, #fff6ea);
  box-shadow: 0 18px 34px rgba(236, 185, 88, 0.18);
  min-width: 176px;
}

:deep(.warm-dropdown .ant-dropdown-menu-item) {
  border-radius: 14px;
  min-height: 42px;
  color: #6f5837;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 2px;

  &:hover {
    background: #fff3d6;
    color: #c98511;
  }
}

:deep(.warm-dropdown .ant-dropdown-menu-item-selected) {
  background: linear-gradient(180deg, #fff0cc, #ffe2a9) !important;
  color: #a86500 !important;
  box-shadow: inset 0 0 0 1px rgba(238, 183, 84, 0.45);
}

:deep(.warm-dropdown .ant-dropdown-menu-item .anticon) {
  font-size: 15px;
  color: #8d6d3d;
}

:deep(.warm-dropdown .ant-dropdown-menu-item-danger) {
  color: #c85a49 !important;
}

:deep(.warm-dropdown .ant-dropdown-menu-item-danger:hover) {
  background: #fff1ee !important;
  color: #b84b3b !important;
}

:deep(.warm-dropdown .ant-dropdown-menu-item-divider) {
  margin: 6px 0;
  background: #f1e1c8;
}

:deep(.ant-modal .ant-input-affix-wrapper),
:deep(.ant-modal .ant-input-password),
:deep(.ant-modal .ant-input) {
  border-radius: 14px;
}

:deep(.ant-modal .ant-btn-primary) {
  background: linear-gradient(180deg, #ffc45b, #ffab25) !important;
  border: none !important;
}

.avatar-modal {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 0 6px;
  text-align: center;
}

.avatar-modal-preview {
  background: linear-gradient(180deg, #ffd06d, #ffb02b);
  color: #5a3c14;
  font-size: 32px;
  font-weight: 700;
  box-shadow: 0 16px 28px rgba(255, 176, 43, 0.18);
}

.avatar-modal-text {
  margin-top: 16px;
  color: #8c7458;
  font-size: 13px;
}

.avatar-upload-btn {
  margin-top: 18px;
}

@media (max-width: 960px) {
  .app-header {
    padding-inline: 12px !important;
  }

  .header-inner {
    padding: 0 14px;
    gap: 12px;
    flex-wrap: wrap;
    height: auto;
    min-height: 74px;
  }

  .header-brand {
    margin-right: 8px;
  }

  .header-menu {
    order: 3;
    width: 100%;
  }

  .header-actions {
    margin-left: 0;
  }
}

@media (max-width: 640px) {
  .brand-sub,
  .user-name {
    display: none;
  }

  .admin-btn {
    padding-inline: 12px;
  }

  .app-content {
    padding-inline: 14px;
  }
}
</style>
