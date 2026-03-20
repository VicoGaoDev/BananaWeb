<script setup lang="ts">
import { ref, reactive, onMounted, h } from "vue";
import { useRouter } from "vue-router";
import { message } from "ant-design-vue";
import { LockOutlined, ThunderboltOutlined, UserOutlined } from "@ant-design/icons-vue";
import { useAuthStore } from "@/stores/auth";
import { login as apiLogin } from "@/api/auth";

const router = useRouter();
const auth = useAuthStore();
const loading = ref(false);
const form = reactive({ username: "", password: "" });

onMounted(() => {
  if (auth.isLoggedIn) router.replace("/generate");
});

async function handleLogin() {
  if (!form.username || !form.password) {
    message.warning("请输入用户名和密码");
    return;
  }
  loading.value = true;
  try {
    const res = await apiLogin(form.username, form.password);
    auth.setAuth(res.token, res.user);
    message.success("登录成功");
    router.push("/generate");
  } catch (err: any) {
    message.error(err.response?.data?.detail || "登录失败");
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-shell">
      <section class="login-hero">
        <div class="hero-badge">Banana Web</div>
        <div class="hero-icon">🍌</div>
        <h1>统一风格的 AI 绘图工作台</h1>
        <p class="hero-desc">
          基于风格模板的 AI 批量出图系统。上传参考图、选择比例与风格，即可快速生成统一视觉的图片结果。
        </p>

        <div class="hero-list">
          <div class="hero-item">
            <span class="hero-dot"></span>
            风格化模板驱动，不暴露 Prompt
          </div>
          <div class="hero-item">
            <span class="hero-dot"></span>
            本地参考图上传与多图结果输出
          </div>
          <div class="hero-item">
            <span class="hero-dot"></span>
            管理后台统一配置风格与 API Key
          </div>
        </div>

        <div class="hero-card">
          <div class="hero-card-title">系统体验</div>
          <div class="hero-card-row">
            <span>风格模板</span>
            <strong>统一输出</strong>
          </div>
          <div class="hero-card-row">
            <span>结果返回</span>
            <strong>实时轮询</strong>
          </div>
          <div class="hero-card-row">
            <span>视觉风格</span>
            <strong>暖色扁平卡片</strong>
          </div>
        </div>
      </section>

      <section class="login-panel">
        <div class="panel-top">
          <div class="panel-kicker">欢迎回来</div>
          <h2>登录系统</h2>
          <p>输入账号密码后进入 Banana Web 控制台。</p>
        </div>

        <a-form layout="vertical" :model="form" @finish="handleLogin" class="login-form">
          <a-form-item label="用户名">
            <a-input
              v-model:value="form.username"
              size="large"
              placeholder="请输入用户名"
              :prefix="h(UserOutlined, { style: { color: '#be9b62' } })"
            />
          </a-form-item>
          <a-form-item label="密码">
            <a-input-password
              v-model:value="form.password"
              size="large"
              placeholder="请输入密码"
              :prefix="h(LockOutlined, { style: { color: '#be9b62' } })"
              @press-enter="handleLogin"
            />
          </a-form-item>
          <a-form-item class="submit-item">
            <a-button
              type="primary"
              html-type="submit"
              size="large"
              :loading="loading"
              block
              class="login-btn"
            >
              <template #icon><ThunderboltOutlined /></template>
              {{ loading ? "登录中..." : "进入工作台" }}
            </a-button>
          </a-form-item>
        </a-form>

        <div class="login-note">
          <span class="note-label">默认管理员</span>
          <strong>admin / admin123</strong>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped lang="scss">
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 28px;
  background:
    radial-gradient(circle at top, rgba(255, 203, 113, 0.18), transparent 26%),
    linear-gradient(180deg, #fff8ee 0%, #fffdf9 100%);
}

.login-shell {
  width: min(1120px, 100%);
  display: grid;
  grid-template-columns: 1.15fr 0.85fr;
  gap: 22px;
}

.login-hero,
.login-panel {
  border-radius: 32px;
  border: 1px solid rgba(241, 210, 154, 0.72);
  background: linear-gradient(180deg, #fffaf0 0%, #fffefb 100%);
  box-shadow: 0 24px 54px rgba(236, 185, 88, 0.14);
}

.login-hero {
  padding: 42px;
  position: relative;
  overflow: hidden;
}

.login-hero::before {
  content: "";
  position: absolute;
  inset: auto -80px -120px auto;
  width: 280px;
  height: 280px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(255, 190, 74, 0.28), transparent 62%);
}

.hero-badge {
  display: inline-flex;
  align-items: center;
  padding: 8px 14px;
  border-radius: 999px;
  background: #fff2d1;
  color: #c98918;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.hero-icon {
  width: 78px;
  height: 78px;
  margin-top: 22px;
  border-radius: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(180deg, #ffd06d, #ffaf29);
  box-shadow: 0 20px 36px rgba(255, 175, 41, 0.24);
  font-size: 42px;
}

.login-hero h1 {
  max-width: 460px;
  margin-top: 24px;
  font-size: 42px;
  line-height: 1.16;
  color: #4c341a;
}

.hero-desc {
  max-width: 500px;
  margin-top: 16px;
  font-size: 15px;
  line-height: 1.9;
  color: #82684d;
}

.hero-list {
  display: grid;
  gap: 14px;
  margin-top: 28px;
}

.hero-item {
  display: flex;
  align-items: center;
  gap: 12px;
  color: #664e30;
  font-size: 15px;
  font-weight: 600;
}

.hero-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: linear-gradient(180deg, #ffcb62, #ffab25);
  box-shadow: 0 0 0 5px rgba(255, 203, 98, 0.18);
  flex-shrink: 0;
}

.hero-card {
  width: min(360px, 100%);
  margin-top: 34px;
  padding: 18px;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.74);
  border: 1px solid #f2dfbf;
  backdrop-filter: blur(8px);
}

.hero-card-title {
  color: #b8883f;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.hero-card-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 14px;
  margin-top: 14px;
  border-top: 1px solid #f3e5cb;
  color: #7d6545;
  font-size: 14px;

  strong {
    color: #4c341a;
  }
}

.login-panel {
  padding: 38px 34px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.panel-top {
  margin-bottom: 28px;

  h2 {
    margin-top: 8px;
    font-size: 32px;
    color: #4c341a;
  }

  p {
    margin-top: 10px;
    color: #8c7458;
    font-size: 14px;
  }
}

.panel-kicker {
  color: #c48a1b;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.login-form {
  :deep(.ant-form-item-label > label) {
    font-weight: 700;
    color: #5f4526;
  }

  :deep(.ant-input-affix-wrapper),
  :deep(.ant-input),
  :deep(.ant-input-password) {
    height: 50px;
    border-radius: 16px;
    border-color: #efdcb9;
    background: #fffdf8;
    box-shadow: none;
  }

  :deep(.ant-input-affix-wrapper:focus),
  :deep(.ant-input-affix-wrapper-focused),
  :deep(.ant-input:focus) {
    border-color: #f0b85a;
    box-shadow: 0 0 0 3px rgba(255, 184, 90, 0.12);
  }
}

.submit-item {
  margin-top: 10px;
  margin-bottom: 0;
}

.login-btn {
  height: 54px;
  border-radius: 18px;
  font-size: 16px;
  font-weight: 700;
  background: linear-gradient(180deg, #ffc45b, #ffab25) !important;
  border: none !important;
  box-shadow: 0 16px 28px rgba(255, 169, 37, 0.28) !important;
}

.login-note {
  margin-top: 22px;
  padding: 14px 16px;
  border-radius: 18px;
  background: #fff6e2;
  border: 1px solid #f2dfbf;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: #7f6747;
  font-size: 13px;

  strong {
    color: #4c341a;
  }
}

.note-label {
  font-weight: 700;
}

@media (max-width: 960px) {
  .login-shell {
    grid-template-columns: 1fr;
  }

  .login-hero h1 {
    font-size: 34px;
  }
}

@media (max-width: 640px) {
  .login-page {
    padding: 16px;
  }

  .login-hero,
  .login-panel {
    padding: 24px 20px;
    border-radius: 24px;
  }

  .login-hero h1 {
    font-size: 28px;
  }

  .login-note {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
