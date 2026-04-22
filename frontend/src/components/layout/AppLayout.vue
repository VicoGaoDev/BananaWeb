<script setup lang="ts">
import { ref, reactive, computed, onMounted, h, provide, nextTick, watch } from "vue";
import { useRouter, useRoute } from "vue-router";
import { useAuthStore } from "@/stores/auth";
import { message } from "ant-design-vue";
import {
  login as apiLogin,
  register as apiRegister,
  changePassword,
  getMe,
  uploadAvatar,
  getContactConfig,
  getAnnouncementConfig,
} from "@/api/auth";
import type { AnnouncementConfig } from "@/types";
import {
  PictureOutlined,
  SettingOutlined,
  TeamOutlined,
  BarChartOutlined,
  KeyOutlined,
  CloudUploadOutlined,
  LogoutOutlined,
  LockOutlined,
  UploadOutlined,
  DownOutlined,
  UserOutlined,
  UserAddOutlined,
  ThunderboltOutlined,
  MenuOutlined,
} from "@ant-design/icons-vue";

const router = useRouter();
const route = useRoute();
const auth = useAuthStore();
const isAdmin = computed(() => auth.isAdmin);
const isSuperAdmin = computed(() => auth.isSuperAdmin);
const mobileDrawerOpen = ref(false);
const routeTransitionName = ref("route-page-forward");

const routeOrder = new Map<string, number>([
  ["/", 0],
  ["/templates", 1],
  ["/generate", 2],
  ["/history", 3],
  ["/credit-logs", 4],
  ["/admin/templates", 5],
  ["/admin/users", 6],
  ["/admin/dashboard", 7],
  ["/admin/api-key", 8],
  ["/admin/cos-config", 9],
  ["/admin/external-api-configs", 10],
]);

const primaryMenuItems = [
  { key: "templates", label: "创意模版", iconSrc: "/nav-templates.svg" },
  { key: "generate", label: "自定义绘图", iconSrc: "/nav-generate.svg" },
  { key: "history", label: "历史记录", iconSrc: "/nav-history.svg" },
];

const adminMenuItems = computed(() =>
  [
    { key: "/admin/templates", label: "模版管理", icon: PictureOutlined, superAdminOnly: false },
    { key: "/admin/users", label: "用户管理", icon: TeamOutlined, superAdminOnly: false },
    { key: "/admin/dashboard", label: "数据统计", icon: BarChartOutlined, superAdminOnly: false },
    { key: "/admin/api-key", label: "配置管理", icon: KeyOutlined, superAdminOnly: false },
    { key: "/admin/cos-config", label: "COS 配置", icon: CloudUploadOutlined, superAdminOnly: true },
    { key: "/admin/external-api-configs", label: "接口管理", icon: KeyOutlined, superAdminOnly: true },
  ].filter((item) => !item.superAdminOnly || isSuperAdmin.value)
);

const userMenuItems = [
  { key: "avatar", label: "上传头像", icon: UploadOutlined, danger: false },
  { key: "password", label: "修改密码", icon: LockOutlined, danger: false },
  { key: "credits", label: "积分记录", icon: ThunderboltOutlined, danger: false },
  { key: "logout", label: "退出登录", icon: LogoutOutlined, danger: true },
];

const selectedKeys = computed(() => {
  const p = route.path;
  if (p.startsWith("/admin")) return ["admin"];
  if (p === "/") return [];
  if (p === "/templates") return ["templates"];
  if (p === "/history") return ["history"];
  return ["generate"];
});

const adminSelectedKeys = computed(() => {
  if (!route.path.startsWith("/admin")) return [];
  return [route.path];
});

watch(
  () => route.path,
  (to, from) => {
    const toRank = routeOrder.get(to) ?? 0;
    const fromRank = routeOrder.get(from ?? "") ?? 0;
    routeTransitionName.value = toRank < fromRank ? "route-page-back" : "route-page-forward";
  },
  { immediate: true }
);

function handleMenuClick({ key }: { key: string }) {
  mobileDrawerOpen.value = false;
  if (key === "templates") router.push("/templates");
  else if (key === "generate") router.push("/generate");
  else if (key === "history") {
    if (!auth.isLoggedIn) {
      loginModalVisible.value = true;
      return;
    }
    router.push("/history");
  }
}

function handleAdminMenu({ key }: { key: string }) {
  mobileDrawerOpen.value = false;
  router.push(key);
}

function handleUserMenu({ key }: { key: string }) {
  mobileDrawerOpen.value = false;
  if (key === "avatar") avatarVisible.value = true;
  else if (key === "password") pwdVisible.value = true;
  else if (key === "credits") router.push("/credit-logs");
  else if (key === "logout") {
    auth.logout();
    router.push("/");
  }
}

const loginModalVisible = ref(false);
provide("loginModalVisible", loginModalVisible);
const authTab = ref<"login" | "register">("login");
const loginForm = reactive({ username: "", password: "" });
const loginLoading = ref(false);
const registerForm = reactive({ username: "", password: "", confirmPassword: "" });
const registerLoading = ref(false);

function openAuthModal(tab: "login" | "register") {
  mobileDrawerOpen.value = false;
  authTab.value = tab;
  loginModalVisible.value = true;
}

function resetAuthForms() {
  loginForm.username = "";
  loginForm.password = "";
  registerForm.username = "";
  registerForm.password = "";
  registerForm.confirmPassword = "";
}

async function handleLoginSubmit() {
  if (!loginForm.username || !loginForm.password) {
    message.warning("请输入用户名和密码");
    return;
  }
  loginLoading.value = true;
  try {
    const res = await apiLogin(loginForm.username, loginForm.password);
    auth.setAuth(res.token, res.user);
    message.success("登录成功");
    loginModalVisible.value = false;
    resetAuthForms();
    await nextTick();
    await checkAnnouncement();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "登录失败");
  } finally {
    loginLoading.value = false;
  }
}

async function handleRegisterSubmit() {
  if (!registerForm.username || !registerForm.password) {
    message.warning("请输入用户名和密码");
    return;
  }
  if (registerForm.password.length < 6) {
    message.warning("密码至少6位");
    return;
  }
  if (registerForm.password !== registerForm.confirmPassword) {
    message.warning("两次密码不一致");
    return;
  }
  registerLoading.value = true;
  try {
    const res = await apiRegister(registerForm.username, registerForm.password);
    auth.setAuth(res.token, res.user);
    message.success("注册成功");
    loginModalVisible.value = false;
    resetAuthForms();
    await nextTick();
    await checkAnnouncement();
  } catch (err: any) {
    message.error(err.response?.data?.detail || "注册失败");
  } finally {
    registerLoading.value = false;
  }
}

const pwdVisible = ref(false);
const pwdForm = ref({ oldPassword: "", newPassword: "", confirmPassword: "" });
const pwdLoading = ref(false);
const avatarVisible = ref(false);
const avatarUploading = ref(false);
const avatarInput = ref<HTMLInputElement | null>(null);
const creditsContactVisible = ref(false);
const contactQrImage = ref("");
const announcementVisible = ref(false);
const announcementDismissToday = ref(false);
const announcementConfig = ref<AnnouncementConfig>({
  announcement_enabled: false,
  announcement_content: "",
  announcement_updated_at: null,
});
const ANNOUNCEMENT_DISMISS_KEY = "systemAnnouncementDismissState";

const avatarUrl = computed(() => auth.user?.avatar_url || "");
const avatarFallback = computed(() => auth.user?.username?.charAt(0)?.toUpperCase() || "U");

function getTodayString() {
  return new Date().toLocaleDateString("en-CA");
}

function getAnnouncementVersion(config: AnnouncementConfig) {
  return config.announcement_updated_at || "";
}

function shouldSuppressAnnouncement(config: AnnouncementConfig) {
  try {
    const raw = localStorage.getItem(ANNOUNCEMENT_DISMISS_KEY);
    if (!raw) return false;
    const parsed = JSON.parse(raw);
    return parsed?.date === getTodayString() && parsed?.version === getAnnouncementVersion(config);
  } catch {
    return false;
  }
}

function handleAnnouncementClose() {
  if (announcementDismissToday.value) {
    localStorage.setItem(ANNOUNCEMENT_DISMISS_KEY, JSON.stringify({
      date: getTodayString(),
      version: getAnnouncementVersion(announcementConfig.value),
    }));
  }
  announcementVisible.value = false;
}

async function checkAnnouncement() {
  try {
    const res = await getAnnouncementConfig();
    announcementConfig.value = res;
    if (!res.announcement_enabled || !res.announcement_content.trim() || shouldSuppressAnnouncement(res)) {
      return;
    }
    announcementDismissToday.value = false;
    announcementVisible.value = true;
  } catch {
    // ignore announcement config failures
  }
}

onMounted(async () => {
  await Promise.allSettled([
    (async () => {
      const res = await getContactConfig();
      contactQrImage.value = res.contact_qr_image || "";
    })(),
    checkAnnouncement(),
  ]);

  if (!auth.isLoggedIn) return;
  try {
    auth.updateUser(await getMe());
  } catch {
    // ignore sync failures for stale sessions
  }
});

function openCreditsContact() {
  mobileDrawerOpen.value = false;
  creditsContactVisible.value = true;
}

function toggleMobileDrawer() {
  mobileDrawerOpen.value = !mobileDrawerOpen.value;
}

watch(
  () => route.fullPath,
  () => {
    mobileDrawerOpen.value = false;
  }
);

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
        <div class="header-brand" @click="router.push('/')">
          <div class="brand-mark">🍌</div>
          <div class="brand-copy">
            <span class="brand-name">Banana Web</span>
            <span class="brand-sub">AI Creative Studio</span>
          </div>
        </div>

        <div class="mobile-nav-entry">
          <div v-if="auth.isLoggedIn" class="mobile-nav-credits" @click="openCreditsContact">
            <ThunderboltOutlined />
            <span>{{ auth.user?.credits ?? 0 }}</span>
          </div>
          <a-button class="mobile-nav-fab" type="primary" shape="circle" @click="toggleMobileDrawer">
            <template #icon><MenuOutlined /></template>
          </a-button>
        </div>

        <a-menu
          mode="horizontal"
          :selected-keys="selectedKeys"
          class="header-menu"
          @click="handleMenuClick"
        >
          <a-menu-item v-for="item in primaryMenuItems" :key="item.key">
            <img :src="item.iconSrc" :alt="item.label" class="nav-menu-icon" />
            <span>{{ item.label }}</span>
          </a-menu-item>
        </a-menu>

        <div class="header-actions">
          <template v-if="auth.isLoggedIn">
            <a-dropdown v-if="isAdmin" :trigger="['click']" overlay-class-name="warm-dropdown">
              <a-button class="admin-btn" type="text">
                <SettingOutlined />
                管理后台
                <DownOutlined style="font-size: 10px; margin-left: 4px" />
              </a-button>
              <template #overlay>
                <a-menu :selected-keys="adminSelectedKeys" @click="handleAdminMenu">
                  <a-menu-item v-for="item in adminMenuItems" :key="item.key">
                    <component :is="item.icon" />
                    <span style="margin-left: 8px">{{ item.label }}</span>
                  </a-menu-item>
                </a-menu>
              </template>
            </a-dropdown>

            <div class="credits-badge" @click="openCreditsContact">
              <ThunderboltOutlined />
              <span>{{ auth.user?.credits ?? 0 }}</span>
            </div>

            <a-dropdown :trigger="['click']" overlay-class-name="warm-dropdown">
              <div class="user-trigger">
                <a-avatar :size="34" class="user-avatar" :src="avatarUrl || undefined">
                  {{ avatarFallback }}
                </a-avatar>
                <span class="user-name">{{ auth.user?.username }}</span>
              </div>
              <template #overlay>
                <a-menu @click="handleUserMenu">
                  <a-menu-item
                    v-for="item in userMenuItems.filter((entry) => !entry.danger)"
                    :key="item.key"
                  >
                    <component :is="item.icon" />
                    <span style="margin-left: 8px">{{ item.label }}</span>
                  </a-menu-item>
                  <a-menu-divider />
                  <a-menu-item
                    v-for="item in userMenuItems.filter((entry) => entry.danger)"
                    :key="item.key"
                    danger
                  >
                    <component :is="item.icon" />
                    <span style="margin-left: 8px">{{ item.label }}</span>
                  </a-menu-item>
                </a-menu>
              </template>
            </a-dropdown>
          </template>

          <template v-else>
            <a-button type="primary" class="login-header-btn" @click="openAuthModal('login')">
              <template #icon><UserOutlined /></template>
              登录
            </a-button>
            <a-button class="register-header-btn" @click="openAuthModal('register')">
              <template #icon><UserAddOutlined /></template>
              注册
            </a-button>
          </template>
        </div>
      </div>
    </a-layout-header>

    <a-layout-content class="app-content">
      <div class="content-inner">
        <router-view v-slot="{ Component, route: currentRoute }">
          <transition :name="routeTransitionName" mode="out-in">
            <div :key="currentRoute.path" class="route-page-shell">
              <component :is="Component" />
            </div>
          </transition>
        </router-view>
      </div>
    </a-layout-content>

    <a-drawer
      v-model:open="mobileDrawerOpen"
      placement="right"
      :width="320"
      class="mobile-nav-drawer"
      title="导航菜单"
    >
      <div class="mobile-drawer-content">
        <div class="mobile-drawer-brand">
          <div class="brand-mark">🍌</div>
          <div class="brand-copy">
            <span class="brand-name">Banana Web</span>
            <span class="brand-sub">AI Creative Studio</span>
          </div>
        </div>

        <div v-if="auth.isLoggedIn" class="mobile-user-card">
          <a-avatar :size="48" class="user-avatar" :src="avatarUrl || undefined">
            {{ avatarFallback }}
          </a-avatar>
          <div class="mobile-user-meta">
            <span class="mobile-user-name">{{ auth.user?.username }}</span>
            <span class="mobile-user-role">
              {{ isSuperAdmin ? "超级管理员" : isAdmin ? "管理员" : "普通用户" }}
            </span>
          </div>
          <div class="mobile-user-credits" @click="openCreditsContact">
            <ThunderboltOutlined />
            <span>{{ auth.user?.credits ?? 0 }}</span>
          </div>
        </div>

        <div class="mobile-drawer-section">
          <div class="mobile-drawer-section-title">功能导航</div>
          <a-menu
            mode="inline"
            :selected-keys="selectedKeys"
            class="mobile-drawer-menu"
            @click="handleMenuClick"
          >
            <a-menu-item v-for="item in primaryMenuItems" :key="item.key">
              <img :src="item.iconSrc" :alt="item.label" class="nav-menu-icon" />
              <span>{{ item.label }}</span>
            </a-menu-item>
          </a-menu>
        </div>

        <div v-if="auth.isLoggedIn && isAdmin" class="mobile-drawer-section">
          <div class="mobile-drawer-section-title">管理后台</div>
          <a-menu
            mode="inline"
            :selected-keys="adminSelectedKeys"
            class="mobile-drawer-menu"
            @click="handleAdminMenu"
          >
            <a-menu-item v-for="item in adminMenuItems" :key="item.key">
              <component :is="item.icon" />
              <span>{{ item.label }}</span>
            </a-menu-item>
          </a-menu>
        </div>

        <div class="mobile-drawer-section">
          <div class="mobile-drawer-section-title">
            {{ auth.isLoggedIn ? "账户操作" : "账户入口" }}
          </div>

          <div v-if="auth.isLoggedIn">
            <a-menu mode="inline" class="mobile-drawer-menu" @click="handleUserMenu">
              <a-menu-item
                v-for="item in userMenuItems"
                :key="item.key"
                :danger="item.danger"
              >
                <component :is="item.icon" />
                <span>{{ item.label }}</span>
              </a-menu-item>
            </a-menu>
          </div>
          <div v-else class="mobile-auth-actions">
            <a-button type="primary" class="login-header-btn" block @click="openAuthModal('login')">
              <template #icon><UserOutlined /></template>
              登录
            </a-button>
            <a-button class="register-header-btn" block @click="openAuthModal('register')">
              <template #icon><UserAddOutlined /></template>
              注册
            </a-button>
          </div>
        </div>
      </div>
    </a-drawer>

    <a-modal
      v-model:open="creditsContactVisible"
      title="联系我们"
      :footer="null"
      :width="420"
      centered
    >
      <div class="credits-contact-modal">
        <div v-if="contactQrImage" class="credits-contact-qr">
          <img :src="contactQrImage" alt="contact qr code" />
        </div>
        <div v-else class="credits-contact-empty">
          暂未配置联系二维码，请联系管理员
        </div>
        <ul class="credits-contact-list">
          <li>积分获取</li>
          <li>API调用</li>
          <li>技术支持</li>
          <li>需求定制</li>
        </ul>
      </div>
    </a-modal>

    <a-modal
      v-model:open="announcementVisible"
      title="系统公告"
      :footer="null"
      :width="520"
      centered
      @cancel="handleAnnouncementClose"
    >
      <div class="announcement-modal">
        <div class="announcement-content">
          {{ announcementConfig.announcement_content }}
        </div>
        <a-checkbox v-model:checked="announcementDismissToday">
          今日不再弹出
        </a-checkbox>
        <div class="announcement-actions">
          <a-button type="primary" class="warm-primary-btn" @click="handleAnnouncementClose">
            知道了
          </a-button>
        </div>
      </div>
    </a-modal>

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
    <a-modal
      v-model:open="loginModalVisible"
      :title="null"
      :footer="null"
      :width="420"
      centered
      @after-close="resetAuthForms"
    >
      <a-tabs v-model:activeKey="authTab" centered class="auth-tabs">
        <a-tab-pane key="login" tab="登录">
          <a-form layout="vertical" :model="loginForm" @finish="handleLoginSubmit" style="margin-top: 8px">
            <a-form-item label="用户名">
              <a-input
                v-model:value="loginForm.username"
                size="large"
                placeholder="请输入用户名"
                :prefix="h(UserOutlined, { style: { color: '#be9b62' } })"
              />
            </a-form-item>
            <a-form-item label="密码">
              <a-input-password
                v-model:value="loginForm.password"
                size="large"
                placeholder="请输入密码"
                :prefix="h(LockOutlined, { style: { color: '#be9b62' } })"
                @press-enter="handleLoginSubmit"
              />
            </a-form-item>
            <a-form-item style="margin-bottom: 8px">
              <a-button
                type="primary"
                html-type="submit"
                size="large"
                :loading="loginLoading"
                block
                class="warm-primary-btn"
              >
                <template #icon><ThunderboltOutlined /></template>
                {{ loginLoading ? "登录中..." : "登录" }}
              </a-button>
            </a-form-item>
            <div class="auth-switch-hint">
              还没有账号？<a @click="authTab = 'register'">立即注册</a>
            </div>
          </a-form>
        </a-tab-pane>

        <a-tab-pane key="register" tab="注册">
          <a-form layout="vertical" :model="registerForm" @finish="handleRegisterSubmit" style="margin-top: 8px">
            <a-form-item label="用户名">
              <a-input
                v-model:value="registerForm.username"
                size="large"
                placeholder="2-20 个字符"
                :prefix="h(UserOutlined, { style: { color: '#be9b62' } })"
                :maxlength="20"
              />
            </a-form-item>
            <a-form-item label="密码">
              <a-input-password
                v-model:value="registerForm.password"
                size="large"
                placeholder="至少 6 位"
                :prefix="h(LockOutlined, { style: { color: '#be9b62' } })"
              />
            </a-form-item>
            <a-form-item label="确认密码">
              <a-input-password
                v-model:value="registerForm.confirmPassword"
                size="large"
                placeholder="请再次输入密码"
                :prefix="h(LockOutlined, { style: { color: '#be9b62' } })"
                @press-enter="handleRegisterSubmit"
              />
            </a-form-item>
            <a-form-item style="margin-bottom: 8px">
              <a-button
                type="primary"
                html-type="submit"
                size="large"
                :loading="registerLoading"
                block
                class="warm-primary-btn"
              >
                <template #icon><UserAddOutlined /></template>
                {{ registerLoading ? "注册中..." : "注册" }}
              </a-button>
            </a-form-item>
            <div class="auth-switch-hint">
              已有账号？<a @click="authTab = 'login'">去登录</a>
            </div>
          </a-form>
        </a-tab-pane>
      </a-tabs>
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
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
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
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  width: max-content;
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

.nav-menu-icon {
  width: 20px;
  height: 20px;
  display: block;
  flex-shrink: 0;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
}

.mobile-nav-fab {
  width: 54px;
  height: 54px;
  display: none;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  border: none !important;
  background: linear-gradient(180deg, #ffc45b, #ffab25) !important;
  box-shadow: 0 16px 30px rgba(255, 169, 37, 0.26);
}

.mobile-nav-entry {
  display: none;
  align-items: center;
  gap: 10px;
  margin-left: auto;
}

.mobile-nav-credits {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 42px;
  padding: 0 14px;
  border-radius: 999px;
  background: rgba(255, 247, 232, 0.92);
  border: 1px solid #efcf93;
  color: #d48806;
  font-weight: 700;
  box-shadow: 0 10px 22px rgba(239, 183, 73, 0.14);
  cursor: pointer;
}

.mobile-drawer-content {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.mobile-drawer-brand {
  display: flex;
  align-items: center;
  gap: 12px;
}

.mobile-user-card {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 12px;
  padding: 16px;
  border-radius: 22px;
  background: linear-gradient(180deg, #fff7e8, #ffefcf);
  border: 1px solid #efcf93;
  box-shadow: 0 12px 24px rgba(239, 183, 73, 0.12);
}

.mobile-user-meta {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.mobile-user-name {
  font-size: 16px;
  font-weight: 700;
  color: #4c341a;
  word-break: break-all;
}

.mobile-user-role {
  font-size: 12px;
  color: #9a7948;
}

.mobile-user-credits {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.7);
  color: #d48806;
  font-weight: 700;
  cursor: pointer;
}

.mobile-drawer-section {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.mobile-drawer-section-title {
  padding-left: 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #b8883f;
}

.mobile-drawer-menu {
  border-inline-end: none !important;
  background: transparent !important;

  :deep(.ant-menu-item) {
    height: 48px;
    line-height: 48px;
    margin: 4px 0 !important;
    border-radius: 16px;
    font-weight: 700;
    color: #6f5837;
  }

  :deep(.ant-menu-item-selected) {
    background: linear-gradient(180deg, #ffd06d, #ffb02b) !important;
    color: #523713 !important;
    box-shadow: 0 10px 18px rgba(255, 176, 43, 0.18);
  }

  :deep(.ant-menu-item-danger) {
    color: #c85a49 !important;
  }

  :deep(.ant-menu-item-danger:hover) {
    background: #fff1ee !important;
    color: #b84b3b !important;
  }
}

.mobile-auth-actions {
  display: flex;
  flex-direction: column;
  gap: 12px;
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

.credits-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 0;
  font-size: 15px;
  font-weight: 700;
  color: #d48806;
  cursor: pointer;
  transition: color 0.2s, transform 0.2s;

  &:hover {
    color: #b87306;
    transform: translateY(-1px);
  }
}

.credits-contact-modal {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 18px;
  padding: 8px 0 4px;
  text-align: center;
}

.credits-contact-list {
  display: grid;
  grid-template-columns: repeat(2, auto);
  justify-content: center;
  justify-items: start;
  column-gap: 28px;
  row-gap: 8px;
  margin: 0 auto;
  width: max-content;
  max-width: 100%;
  padding: 0 0 0 1.15em;
  box-sizing: border-box;
  list-style: disc;
  list-style-position: outside;
  text-align: left;
  color: #7b6544;
  font-size: 14px;
  line-height: 1.6;

  li {
    display: list-item;

    &::marker {
      font-size: 0.75em;
      color: #a88e68;
    }
  }
}

.credits-contact-qr {
  width: 240px;
  height: 240px;
  padding: 10px;
  border-radius: 24px;
  background: #fffaf1;
  border: 1px solid #f1dfbf;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.65);

  img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    border-radius: 18px;
    background: #fff;
  }
}

.credits-contact-empty {
  width: 100%;
  padding: 26px 18px;
  border-radius: 20px;
  background: #fffaf1;
  border: 1px dashed #e8c88f;
  color: #9a7a52;
  line-height: 1.8;
}

.announcement-modal {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 6px 0 2px;
}

.announcement-content {
  white-space: pre-wrap;
  line-height: 1.85;
  color: #6b5436;
  font-size: 14px;
  padding: 16px 18px;
  border-radius: 18px;
  background: #fffaf1;
  border: 1px solid #f1dfbf;
}

.announcement-actions {
  display: flex;
  justify-content: flex-end;
}

.app-content {
  padding: 22px 24px 28px;
}

.content-inner {
  max-width: 1400px;
  margin: 0 auto;
  position: relative;
}

.route-page-shell {
  min-width: 0;
}

.route-page-forward-enter-active,
.route-page-forward-leave-active,
.route-page-back-enter-active,
.route-page-back-leave-active {
  transition:
    opacity var(--motion-duration-reveal-fast) var(--motion-ease-soft),
    transform var(--motion-duration-reveal) var(--motion-ease-enter),
    filter var(--motion-duration-reveal-fast) var(--motion-ease-soft);
}

.route-page-forward-enter-from {
  opacity: 0;
  transform: translate3d(18px, 0, 0);
  filter: blur(8px);
}

.route-page-forward-leave-to {
  opacity: 0;
  transform: translate3d(-14px, 0, 0);
  filter: blur(6px);
}

.route-page-back-enter-from {
  opacity: 0;
  transform: translate3d(-18px, 0, 0);
  filter: blur(8px);
}

.route-page-back-leave-to {
  opacity: 0;
  transform: translate3d(14px, 0, 0);
  filter: blur(6px);
}

.route-page-forward-enter-to,
.route-page-forward-leave-from,
.route-page-back-enter-to,
.route-page-back-leave-from {
  opacity: 1;
  transform: translate3d(0, 0, 0);
  filter: blur(0);
}

@media (prefers-reduced-motion: reduce) {
  .route-page-forward-enter-active,
  .route-page-forward-leave-active,
  .route-page-back-enter-active,
  .route-page-back-leave-active {
    transition: none !important;
  }
}

:deep(.mobile-nav-drawer .ant-drawer-header) {
  padding: 20px 20px 0;
  border-bottom: none;
  background: linear-gradient(180deg, #fffdf8, #fff9ef);
}

:deep(.mobile-nav-drawer .ant-drawer-title) {
  color: #4c341a;
  font-weight: 700;
}

:deep(.mobile-nav-drawer .ant-drawer-body) {
  padding: 18px 20px 24px;
  background: linear-gradient(180deg, #fffdf8, #fff6ea);
}

:deep(.warm-dropdown .ant-dropdown-menu) {
  padding: 12px;
  border-radius: 24px;
  border: 1px solid #f1dfbf;
  background: linear-gradient(180deg, #fffdfa, #fff8ef);
  box-shadow: 0 16px 28px rgba(164, 122, 47, 0.1);
  min-width: 176px;
}

:deep(.warm-dropdown .ant-dropdown-menu-item) {
  border-radius: 18px;
  min-height: 50px;
  padding: 10px 14px;
  color: #54463a;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 6px;
  transition:
    background var(--motion-duration-fast) var(--motion-ease-soft),
    color var(--motion-duration-fast) var(--motion-ease-soft),
    box-shadow var(--motion-duration-fast) var(--motion-ease-soft);

  &:hover {
    background: rgba(245, 240, 232, 0.9);
    color: #80591f;
  }
}

:deep(.warm-dropdown .ant-dropdown-menu-item-selected) {
  background: linear-gradient(180deg, #f6f2eb, #f1ece4) !important;
  color: #956625 !important;
  box-shadow: inset 0 0 0 1px rgba(233, 223, 206, 0.9);
}

:deep(.warm-dropdown .ant-dropdown-menu-item .anticon) {
  font-size: 15px;
  color: #463f39;
}

:deep(.warm-dropdown .ant-dropdown-menu-item-danger) {
  color: #c85a49 !important;
}

:deep(.warm-dropdown .ant-dropdown-menu-item-danger:hover) {
  background: linear-gradient(180deg, #fff4f1, #ffede8) !important;
  color: #b84b3b !important;
}

:deep(.warm-dropdown .ant-dropdown-menu-item-divider) {
  margin: 8px 2px;
  background: #efe4d2;
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

.login-header-btn {
  height: 42px;
  padding-inline: 20px;
  border-radius: 999px;
  font-weight: 700;
  background: linear-gradient(180deg, #ffc45b, #ffab25) !important;
  border: none !important;
  box-shadow: 0 10px 22px rgba(255, 169, 37, 0.22);
}

.register-header-btn {
  height: 42px;
  padding-inline: 20px;
  border-radius: 999px;
  font-weight: 700;
  border: 1px solid #efcf93 !important;
  background: linear-gradient(180deg, #fff7e8, #ffefcf) !important;
  color: #b26c04 !important;
  box-shadow: 0 10px 22px rgba(239, 183, 73, 0.16);

  &:hover {
    color: #995b00 !important;
    border-color: #eab65d !important;
    background: linear-gradient(180deg, #fff2da, #ffe7b8) !important;
  }
}

.auth-tabs {
  :deep(.ant-tabs-nav) {
    margin-bottom: 4px;
  }

  :deep(.ant-tabs-tab) {
    font-weight: 700;
    font-size: 15px;
    color: #8c7458;
  }

  :deep(.ant-tabs-tab-active .ant-tabs-tab-btn) {
    color: #c98511 !important;
  }

  :deep(.ant-tabs-ink-bar) {
    background: linear-gradient(90deg, #ffc45b, #ffab25);
    height: 3px;
    border-radius: 2px;
  }
}

.auth-switch-hint {
  text-align: center;
  font-size: 13px;
  color: #8c7458;

  a {
    color: #d38a12;
    font-weight: 600;
    cursor: pointer;

    &:hover {
      color: #b26c04;
    }
  }
}

@media (max-width: 960px) {
  .app-header {
    padding-inline: 12px !important;
    height: auto;
  }

  .header-inner {
    padding: 0 16px;
    gap: 12px;
    height: 74px;
    min-height: 74px;
  }

  .header-brand {
    margin-right: 0;
  }

  .header-menu {
    display: none;
  }

  .header-actions {
    display: none;
  }

  .mobile-nav-entry {
    display: inline-flex;
  }

  .mobile-nav-fab {
    display: inline-flex;
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

  :deep(.mobile-nav-drawer .ant-drawer-content-wrapper) {
    width: min(88vw, 320px) !important;
  }
}
</style>
