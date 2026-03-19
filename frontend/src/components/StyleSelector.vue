<script setup lang="ts">
import { computed } from "vue";
import { CheckCircleFilled } from "@ant-design/icons-vue";
import type { Style } from "@/types";

const props = defineProps<{
  styles: Style[];
  modelValue: number | null;
  open: boolean;
}>();

const emit = defineEmits<{
  "update:modelValue": [value: number];
  "update:open": [value: boolean];
}>();

const selectedStyle = computed(() =>
  props.styles.find((s) => s.id === props.modelValue)
);

function select(id: number) {
  emit("update:modelValue", id);
  emit("update:open", false);
}

function handleClose() {
  emit("update:open", false);
}
</script>

<template>
  <a-drawer
    :open="open"
    title="选择风格"
    placement="bottom"
    :height="420"
    :body-style="{ padding: '16px 24px' }"
    :header-style="{ borderBottom: '1px solid #f0f0f0' }"
    @close="handleClose"
  >
    <div class="picker-grid">
      <div
        v-for="style in props.styles"
        :key="style.id"
        :class="['picker-item', { active: modelValue === style.id }]"
        @click="select(style.id)"
      >
        <div class="picker-cover">
          <img v-if="style.cover_image" :src="style.cover_image" :alt="style.name" />
          <div v-else class="picker-cover-ph">
            <span>{{ style.name.charAt(0) }}</span>
          </div>
          <CheckCircleFilled v-if="modelValue === style.id" class="check-icon" />
        </div>
        <div class="picker-label">{{ style.name }}</div>
        <div v-if="style.description" class="picker-desc">{{ style.description }}</div>
      </div>
    </div>
  </a-drawer>
</template>

<style scoped lang="scss">
.picker-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(155px, 1fr));
  gap: 16px;
}

.picker-item {
  background: #fff;
  border: 2px solid transparent;
  border-radius: 10px;
  overflow: hidden;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);

  &:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    transform: translateY(-2px);
  }

  &.active {
    border-color: var(--primary);
  }
}

.picker-cover {
  width: 100%;
  aspect-ratio: 4 / 3;
  overflow: hidden;
  position: relative;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.picker-cover-ph {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1890ff, #722ed1);

  span {
    font-size: 30px;
    font-weight: 700;
    color: rgba(255, 255, 255, 0.85);
  }
}

.check-icon {
  position: absolute;
  top: 8px;
  right: 8px;
  font-size: 22px;
  color: var(--primary);
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.2));
}

.picker-label {
  padding: 10px 12px 2px;
  font-size: 13px;
  font-weight: 600;
  color: var(--text);
}

.picker-desc {
  padding: 2px 12px 10px;
  font-size: 12px;
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
