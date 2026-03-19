<script setup lang="ts">
import { ref, reactive, onMounted, h } from "vue";
import { useRouter } from "vue-router";
import { message } from "ant-design-vue";
import { UserOutlined, LockOutlined } from "@ant-design/icons-vue";
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
    <div class="login-container">
      <div class="login-left">
        <div class="left-content">
          <h1>🍌 Banana Web</h1>
          <p class="tagline">AI 智能绘图平台</p>
          <p class="desc">
            基于风格模板的 AI 批量出图系统<br />
            选择风格，一键生成精美图片
          </p>
          <div class="features">
            <div class="feature-item">
              <span class="feature-dot"></span>
              多种风格模板
            </div>
            <div class="feature-item">
              <span class="feature-dot"></span>
              批量智能生成
            </div>
            <div class="feature-item">
              <span class="feature-dot"></span>
              高品质 4K 输出
            </div>
          </div>
        </div>
      </div>

      <div class="login-right">
        <div class="login-card">
          <h2>登录</h2>
          <p class="login-sub">输入账号密码进入系统</p>

          <a-form layout="vertical" :model="form" @finish="handleLogin" style="margin-top: 32px">
            <a-form-item label="用户名">
              <a-input
                v-model:value="form.username"
                size="large"
                placeholder="请输入用户名"
                :prefix="h(UserOutlined, { style: { color: '#bfbfbf' } })"
              />
            </a-form-item>
            <a-form-item label="密码">
              <a-input-password
                v-model:value="form.password"
                size="large"
                placeholder="请输入密码"
                :prefix="h(LockOutlined, { style: { color: '#bfbfbf' } })"
                @press-enter="handleLogin"
              />
            </a-form-item>
            <a-form-item style="margin-top: 8px">
              <a-button
                type="primary"
                html-type="submit"
                size="large"
                :loading="loading"
                block
                class="login-btn"
              >
                登 录
              </a-button>
            </a-form-item>
          </a-form>

          <div class="login-footer">
            默认管理员账号: admin / admin123
          </div>
        </div>
      </div>
    </div>
  </div>
</template>


<style scoped lang="scss">
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg);
  padding: 24px;
}

.login-container {
  display: flex;
  width: 900px;
  max-width: 100%;
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.07);
  overflow: hidden;
}

.login-left {
  width: 400px;
  background: linear-gradient(135deg, #1890ff 0%, #096dd9 100%);
  padding: 60px 48px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  color: #fff;

  h1 {
    font-size: 28px;
    font-weight: 700;
    margin-bottom: 8px;
  }

  .tagline {
    font-size: 16px;
    opacity: 0.9;
    margin-bottom: 24px;
  }

  .desc {
    font-size: 14px;
    line-height: 1.8;
    opacity: 0.75;
    margin-bottom: 32px;
  }
}

.features {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.feature-item {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  opacity: 0.9;
}

.feature-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.8);
  flex-shrink: 0;
}

.login-right {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48px;
}

.login-card {
  width: 100%;
  max-width: 360px;

  h2 {
    font-size: 24px;
    font-weight: 700;
    margin-bottom: 4px;
    color: var(--text);
  }

  .login-sub {
    font-size: 14px;
    color: var(--text-secondary);
  }
}

.login-btn {
  height: 48px;
  font-size: 16px;
  font-weight: 600;
  border-radius: 8px;
}

.login-footer {
  text-align: center;
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 16px;
}

@media (max-width: 768px) {
  .login-left {
    display: none;
  }

  .login-container {
    width: 420px;
  }
}
</style>
