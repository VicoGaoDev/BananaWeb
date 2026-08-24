<script setup lang="ts">
import { computed } from "vue";
import { CloseOutlined } from "@ant-design/icons-vue";
import { getGenerateStyleById } from "@/lib/generateStyles";

const props = defineProps<{
  colorStyleId: string;
  lightingStyleId: string;
}>();

const emit = defineEmits<{
  "update:colorStyleId": [value: string];
  "update:lightingStyleId": [value: string];
}>();

const colorStyle = computed(() => getGenerateStyleById(props.colorStyleId));
const lightingStyle = computed(() => getGenerateStyleById(props.lightingStyleId));
const hasTags = computed(() => Boolean(colorStyle.value || lightingStyle.value));

function clearColor() {
  emit("update:colorStyleId", "");
}

function clearLighting() {
  emit("update:lightingStyleId", "");
}
</script>

<template>
  <div v-if="hasTags" class="prompt-style-tags">
    <span v-if="colorStyle" class="prompt-style-tag">
      <svg class="prompt-style-tag-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 3.5c-5.1 0-8.5 3.6-8.5 7.4 0 2.6 1.8 4.4 4.2 4.4 1.1 0 1.8-.5 2.1-1.3.2-.5.7-1.7 1.5-1.7.7 0 1 .7 1 1.6 0 2.5-1.5 5.6 1.7 5.6 4.4 0 7.5-3.8 7.5-8.1C21.5 6.7 17.6 3.5 12 3.5Z" />
        <circle cx="8.1" cy="9.1" r="1.15" />
        <circle cx="11.2" cy="7.35" r="1.15" />
        <circle cx="14.7" cy="8.15" r="1.15" />
        <circle cx="16.15" cy="11.35" r="1.15" />
      </svg>
      <span>{{ colorStyle.name }}</span>
      <button type="button" class="prompt-style-tag-clear" aria-label="取消色彩风格" @click="clearColor">
        <CloseOutlined />
      </button>
    </span>
    <span v-if="lightingStyle" class="prompt-style-tag">
      <svg class="prompt-style-tag-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 3.5c-5.1 0-8.5 3.6-8.5 7.4 0 2.6 1.8 4.4 4.2 4.4 1.1 0 1.8-.5 2.1-1.3.2-.5.7-1.7 1.5-1.7.7 0 1 .7 1 1.6 0 2.5-1.5 5.6 1.7 5.6 4.4 0 7.5-3.8 7.5-8.1C21.5 6.7 17.6 3.5 12 3.5Z" />
        <circle cx="8.1" cy="9.1" r="1.15" />
        <circle cx="11.2" cy="7.35" r="1.15" />
        <circle cx="14.7" cy="8.15" r="1.15" />
        <circle cx="16.15" cy="11.35" r="1.15" />
      </svg>
      <span>{{ lightingStyle.name }}</span>
      <button type="button" class="prompt-style-tag-clear" aria-label="取消光影" @click="clearLighting">
        <CloseOutlined />
      </button>
    </span>
  </div>
</template>

<style scoped lang="scss">
.prompt-style-tags {
  position: absolute;
  top: 10px;
  left: 12px;
  right: 16px;
  z-index: 2;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  pointer-events: none;
}

.prompt-style-tag {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  max-width: 100%;
  height: 26px;
  padding: 0 6px 0 8px;
  border-radius: 8px;
  background: rgba(61, 47, 34, 0.08);
  color: var(--theme-title);
  font-size: 12px;
  font-weight: 600;
  line-height: 1;
  pointer-events: auto;
}

.prompt-style-tag-icon {
  flex: 0 0 auto;
  width: 13px;
  height: 13px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.6;
  stroke-linejoin: round;
}

.prompt-style-tag-icon circle {
  fill: currentColor;
  stroke: none;
}

.prompt-style-tag-clear {
  appearance: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  padding: 0;
  border: none;
  border-radius: 50%;
  background: transparent;
  color: inherit;
  font-size: 9px;
  cursor: pointer;
  opacity: 0.55;

  &:hover {
    opacity: 1;
    background: rgba(0, 0, 0, 0.08);
  }
}

html:is([data-theme="dark"], [data-theme="midnight"]) .prompt-style-tag {
  background: rgba(255, 255, 255, 0.12);
  color: #fff;
}

html:is([data-theme="dark"], [data-theme="midnight"]) .prompt-style-tag-clear:hover {
  background: rgba(255, 255, 255, 0.14);
}
</style>
