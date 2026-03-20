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
  background: linear-gradient(180deg, #fffdf8, #fff7ea);
  border: 1px solid #f0ddbb;
  border-radius: 18px;
  overflow: hidden;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 10px 20px rgba(244, 182, 84, 0.08);

  &:hover {
    box-shadow: 0 16px 28px rgba(244, 182, 84, 0.14);
    transform: translateY(-2px);
  }

  &.active {
    border-color: #ffb133;
    box-shadow: 0 16px 28px rgba(255, 177, 51, 0.18);
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
  background: linear-gradient(135deg, #ffd677, #ffaf26);

  span {
    font-size: 30px;
    font-weight: 700;
    color: rgba(94, 62, 9, 0.85);
  }
}

.check-icon {
  position: absolute;
  top: 8px;
  right: 8px;
  font-size: 22px;
  color: #ff9f1a;
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.2));
}

.picker-label {
  padding: 10px 12px 2px;
  font-size: 13px;
  font-weight: 600;
  color: #48321a;
}

.picker-desc {
  padding: 2px 12px 10px;
  font-size: 12px;
  color: #8f7558;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

:deep(.ant-drawer-header) {
  background: #fff9ef;
}

:deep(.ant-drawer-title) {
  color: #48321a;
  font-weight: 700;
}

:deep(.ant-drawer-body) {
  background: #fffdf8;
}
</style>
