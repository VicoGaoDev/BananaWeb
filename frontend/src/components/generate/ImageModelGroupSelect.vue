<script setup lang="ts">
import { computed } from "vue";
import { groupImageModelFilterOptions, type ImageModelFilterOption } from "@/lib/imageModelScene";

defineOptions({ inheritAttrs: false });

const props = defineProps<{
  options: ImageModelFilterOption[];
}>();

const modelValue = defineModel<string | undefined>("value");

const emit = defineEmits<{
  change: [value: string | undefined];
}>();

const grouped = computed(() => groupImageModelFilterOptions(props.options));

function handleChange(value: string | undefined) {
  emit("change", value);
}
</script>

<template>
  <a-select
    v-bind="$attrs"
    v-model:value="modelValue"
    allow-clear
    show-search
    option-filter-prop="label"
    popup-class-name="image-model-group-select-dropdown"
    @change="handleChange"
  >
    <a-select-opt-group
      v-for="group in grouped.groups"
      :key="group.label"
      :label="group.label"
    >
      <a-select-option
        v-for="option in group.options"
        :key="option.value"
        :value="option.value"
        :label="option.label"
      >
        {{ option.label }}
      </a-select-option>
    </a-select-opt-group>
    <a-select-option
      v-for="option in grouped.flatOptions"
      :key="option.value"
      :value="option.value"
      :label="option.label"
    >
      {{ option.label }}
    </a-select-option>
  </a-select>
</template>

<style>
.image-model-group-select-dropdown .ant-select-item-group {
  margin-top: 2px;
  padding-top: 8px;
  color: #5d4526;
  font-size: 15px;
  font-weight: 700;
  line-height: 1.4;
}

.image-model-group-select-dropdown .ant-select-item-group:not(:first-child) {
  margin-top: 6px;
  border-top: 1px solid var(--theme-border, #ead9c0);
}
</style>
