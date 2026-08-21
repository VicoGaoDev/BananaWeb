<script setup lang="ts">
import { message } from "ant-design-vue";
import { BgColorsOutlined, CheckOutlined, RightOutlined } from "@ant-design/icons-vue";
import { appThemes, getAppThemeGroups, type AppThemeName } from "@/config/theme";
import { setAppTheme } from "@/lib/theme";

const props = defineProps<{
  currentTheme: AppThemeName;
}>();

const themeMenuGroups = getAppThemeGroups();

function applyTheme(theme: AppThemeName) {
  if (theme === props.currentTheme) return;
  setAppTheme(theme);
  message.success(`已切换为${appThemes[theme].label}`);
}

function getThemePopupContainer(trigger: HTMLElement) {
  return trigger.closest(".ant-dropdown") || document.body;
}
</script>

<template>
  <a-dropdown
    :trigger="['hover']"
    placement="rightBottom"
    :auto-adjust-overflow="true"
    :mouse-enter-delay="0.05"
    :align="{ offset: [10, 0], overflow: { adjustX: true, adjustY: true } }"
    :get-popup-container="getThemePopupContainer"
    overlay-class-name="theme-style-overlay"
  >
    <div class="theme-style-entry" @click.stop>
      <BgColorsOutlined />
      <span>主题风格</span>
      <RightOutlined class="theme-style-entry-arrow" />
    </div>
    <template #overlay>
      <div class="theme-style-panel" @click.stop>
        <div
          v-for="group in themeMenuGroups"
          :key="group.key"
          class="theme-style-group"
        >
          <div class="theme-style-group-label">{{ group.label }}</div>
          <button
            v-for="option in group.themes"
            :key="option.key"
            type="button"
            class="theme-style-option"
            :class="{ 'is-active': currentTheme === option.key }"
            @click="applyTheme(option.key)"
          >
            <a-tooltip
              placement="right"
              :mouse-enter-delay="0.05"
              overlay-class-name="theme-swatch-tooltip"
            >
              <template #title>
                <div class="theme-menu-swatches">
                  <div
                    v-for="swatch in option.palette"
                    :key="swatch.label"
                    class="theme-menu-swatch"
                  >
                    <span class="theme-menu-swatch-chip" :style="{ background: swatch.color }" />
                    <span>{{ swatch.label }}</span>
                  </div>
                </div>
              </template>
              <span class="theme-menu-item-title">
                <span>{{ option.label }}</span>
                <CheckOutlined v-if="currentTheme === option.key" class="theme-menu-check" />
              </span>
            </a-tooltip>
          </button>
        </div>
      </div>
    </template>
  </a-dropdown>
</template>

<style scoped lang="scss">
.theme-style-entry {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-height: 50px;
  padding: 10px 16px;
  border-radius: 14px;
  color: var(--theme-title);
  font-weight: 700;
  line-height: 1.2;
  cursor: pointer;
  transition:
    background var(--motion-duration-fast) var(--motion-ease-soft),
    color var(--motion-duration-fast) var(--motion-ease-soft),
    box-shadow var(--motion-duration-fast) var(--motion-ease-soft),
    transform var(--motion-duration-fast) var(--motion-ease-soft);
}

.theme-style-entry:hover {
  background: linear-gradient(180deg, var(--theme-panel-bg-soft), var(--theme-panel-bg-strong));
  color: var(--theme-accent-text-hover);
  box-shadow: 0 10px 22px var(--theme-card-shadow);
  transform: translateY(-1px);
}

.theme-style-entry :deep(.anticon) {
  font-size: 16px;
}

.theme-style-entry-arrow {
  margin-left: auto;
  font-size: 10px !important;
}

.theme-style-panel {
  min-width: 176px;
  max-height: min(64vh, 420px);
  padding: 10px;
  overflow-x: hidden;
  overflow-y: auto;
}

.theme-style-group + .theme-style-group {
  margin-top: 6px;
}

.theme-style-group-label {
  padding: 6px 12px 4px;
  color: var(--theme-text-muted);
  font-size: 12px;
  font-weight: 700;
}

.theme-style-option {
  display: flex;
  align-items: center;
  width: 100%;
  min-height: 40px;
  padding: 8px 12px;
  border: 0;
  border-radius: 12px;
  background: transparent;
  color: var(--theme-title);
  font-weight: 700;
  text-align: left;
  cursor: pointer;
}

.theme-style-option:hover,
.theme-style-option.is-active {
  background: var(--theme-control-hover-bg);
  color: var(--theme-accent-text);
}

.theme-menu-item-title {
  display: inline-flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  width: 100%;
}

.theme-menu-check {
  color: var(--theme-accent);
  font-size: 14px;
}
</style>

<style lang="scss">
.theme-style-overlay {
  z-index: 1400 !important;
  overflow: visible;
}

.theme-style-overlay .theme-style-panel {
  min-width: 176px;
  max-height: min(70vh, 440px);
  padding: 10px;
  overflow-x: hidden;
  overflow-y: auto;
  border-radius: 18px;
  border: 1px solid var(--theme-panel-border);
  background: linear-gradient(180deg, var(--theme-panel-bg), var(--theme-panel-bg-soft));
  box-shadow: 0 16px 28px var(--theme-shadow-soft);
}
</style>
