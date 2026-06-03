<script setup lang="ts">
import { onMounted, ref } from "vue";
import { message } from "ant-design-vue";
import { BgColorsOutlined, SettingOutlined } from "@ant-design/icons-vue";
import { appThemes, type AppThemeName } from "@/config/theme";
import { getCurrentTheme, setAppTheme } from "@/lib/theme";

const currentTheme = ref<AppThemeName>(getCurrentTheme());

const themeOptions = [
  { label: appThemes.midnight.label, value: appThemes.midnight.key },
  { label: appThemes.dark.label, value: appThemes.dark.key },
  { label: appThemes.warm.label, value: appThemes.warm.key },
] as const;

onMounted(() => {
  currentTheme.value = getCurrentTheme();
});

function applyThemeSelection() {
  setAppTheme(currentTheme.value);
  message.success(`已切换为${appThemes[currentTheme.value].label}`);
}
</script>

<template>
  <div class="settings-page warm-page motion-page-enter">
    <div class="warm-page-header motion-fade-up" style="--motion-delay: 40ms">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <SettingOutlined />
        </div>
        <div>
          <div class="warm-page-title">设置</div>
          <div class="warm-page-desc">在这里调整当前浏览器主题。主题仅保存在本地浏览器中。</div>
        </div>
      </div>
    </div>

    <div class="theme-card warm-card motion-fade-up motion-card-lift" style="--motion-delay: 120ms">
      <div class="theme-section theme-section-standalone">
        <div class="theme-section-head">
          <div>
            <div class="settings-label">前端主题风格</div>
            <div class="theme-tip">仅作用于当前浏览器，本地保存。刷新或重新打开后会继续使用所选主题。</div>
          </div>
          <BgColorsOutlined class="theme-section-icon" />
        </div>

        <a-radio-group
          v-model:value="currentTheme"
          class="warm-radio-group theme-radio-group"
          button-style="solid"
        >
          <a-radio-button
            v-for="option in themeOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </a-radio-button>
        </a-radio-group>

        <div class="theme-actions">
          <a-button type="primary" class="warm-primary-btn" @click="applyThemeSelection">
            应用主题
          </a-button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.settings-page {
  max-width: 820px;
}

.theme-card {
  padding: 32px;
}

.settings-label {
  font-size: 13px;
  font-weight: 700;
  color: var(--theme-subtitle);
  margin-bottom: 12px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.theme-section {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 22px 24px;
  border-radius: 22px;
  background: linear-gradient(180deg, var(--theme-panel-bg), var(--theme-panel-bg-soft));
  border: 1px solid var(--theme-panel-border);
}

.theme-section-standalone {
  margin-top: 0;
}

.theme-section-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.theme-section-icon {
  font-size: 22px;
  color: var(--theme-accent-text);
}

.theme-tip {
  color: var(--text-secondary);
  line-height: 1.6;
  font-size: 13px;
}

.theme-radio-group {
  width: fit-content;
}

.theme-actions {
  display: flex;
  justify-content: flex-end;
}
</style>
