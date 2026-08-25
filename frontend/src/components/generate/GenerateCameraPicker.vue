<script setup lang="ts">
import { computed, ref } from "vue";
import { CheckOutlined, DownOutlined, UpOutlined } from "@ant-design/icons-vue";
import { withBaseUrl } from "@/lib/assets";
import {
  apertureOpeningRadius,
  emptyGenerateCameraSelection,
  formatGenerateCameraPresetMeta,
  formatSelectedGenerateCameraLabel,
  generateCameraCategories,
  generateCameraPresetGroups,
  generateCameraPresets,
  getGenerateCameraCategory,
  hasSelectedGenerateCamera,
  matchGenerateCameraPreset,
  selectionFromCameraPreset,
  type GenerateCameraCategoryId,
  type GenerateCameraItem,
  type GenerateCameraPreset,
  type GenerateCameraSelection,
} from "@/lib/generateCameras";

const props = defineProps<{
  bodyId: string;
  lensId: string;
  focalId: string;
  apertureId: string;
}>();

const emit = defineEmits<{
  "update:bodyId": [value: string];
  "update:lensId": [value: string];
  "update:focalId": [value: string];
  "update:apertureId": [value: string];
}>();

const open = ref(false);
const draft = ref<GenerateCameraSelection>({ ...emptyGenerateCameraSelection });

const selectedLabel = computed(() => (
  formatSelectedGenerateCameraLabel({
    bodyId: props.bodyId,
    lensId: props.lensId,
    focalId: props.focalId,
    apertureId: props.apertureId,
  }) || "未选择"
));
const hasSelection = computed(() => hasSelectedGenerateCamera({
  bodyId: props.bodyId,
  lensId: props.lensId,
  focalId: props.focalId,
  apertureId: props.apertureId,
}));
const activePresetId = computed(() => matchGenerateCameraPreset(draft.value)?.id || "");
const brokenThumbnails = ref<Record<string, boolean>>({});

function currentId(categoryId: GenerateCameraCategoryId) {
  if (categoryId === "body") return draft.value.bodyId;
  if (categoryId === "lens") return draft.value.lensId;
  if (categoryId === "focal") return draft.value.focalId;
  return draft.value.apertureId;
}

function setCurrentId(categoryId: GenerateCameraCategoryId, value: string) {
  if (categoryId === "body") draft.value = { ...draft.value, bodyId: value };
  else if (categoryId === "lens") draft.value = { ...draft.value, lensId: value };
  else if (categoryId === "focal") draft.value = { ...draft.value, focalId: value };
  else draft.value = { ...draft.value, apertureId: value };
}

function categoryItems(categoryId: GenerateCameraCategoryId) {
  return getGenerateCameraCategory(categoryId)?.items || [];
}

function currentIndex(categoryId: GenerateCameraCategoryId) {
  const id = currentId(categoryId);
  if (!id) return -1;
  return categoryItems(categoryId).findIndex((item) => item.id === id);
}

function neighborItem(categoryId: GenerateCameraCategoryId, offset: number): GenerateCameraItem | null {
  const items = categoryItems(categoryId);
  if (!items.length) return null;
  const index = currentIndex(categoryId);
  if (index < 0) return offset === 0 ? null : items[offset < 0 ? items.length - 1 : 0] || null;
  const next = (index + offset + items.length) % items.length;
  if (offset !== 0 && next === index) return null;
  return items[next] || null;
}

function step(categoryId: GenerateCameraCategoryId, offset: number) {
  const next = neighborItem(categoryId, offset);
  if (next) setCurrentId(categoryId, next.id);
}

function selectItem(categoryId: GenerateCameraCategoryId, item: GenerateCameraItem) {
  setCurrentId(categoryId, currentId(categoryId) === item.id ? "" : item.id);
}

function handleWheel(categoryId: GenerateCameraCategoryId, event: WheelEvent) {
  event.preventDefault();
  step(categoryId, event.deltaY > 0 ? 1 : -1);
}

function firstItemId(categoryId: GenerateCameraCategoryId) {
  return categoryItems(categoryId)[0]?.id || "";
}

function withDefaultFirstItems(selection: GenerateCameraSelection): GenerateCameraSelection {
  return {
    bodyId: selection.bodyId || firstItemId("body"),
    lensId: selection.lensId || firstItemId("lens"),
    focalId: selection.focalId || firstItemId("focal"),
    apertureId: selection.apertureId || firstItemId("aperture"),
  };
}

function defaultDraft(selection: GenerateCameraSelection): GenerateCameraSelection {
  if (hasSelectedGenerateCamera(selection)) {
    return withDefaultFirstItems(selection);
  }
  const firstPreset = generateCameraPresets[0];
  return firstPreset ? selectionFromCameraPreset(firstPreset) : withDefaultFirstItems(selection);
}

function applyPreset(preset: GenerateCameraPreset) {
  draft.value = selectionFromCameraPreset(preset);
}

function openDialog() {
  draft.value = defaultDraft({
    bodyId: props.bodyId,
    lensId: props.lensId,
    focalId: props.focalId,
    apertureId: props.apertureId,
  });
  open.value = true;
}

function closeDialog() {
  open.value = false;
}

function confirmSelection() {
  emit("update:bodyId", draft.value.bodyId);
  emit("update:lensId", draft.value.lensId);
  emit("update:focalId", draft.value.focalId);
  emit("update:apertureId", draft.value.apertureId);
  open.value = false;
}

function displayName(item: GenerateCameraItem | null, fallback = "未选择") {
  return item?.name || fallback;
}

function thumbnailUrl(item: GenerateCameraItem | null) {
  return item?.thumbnail ? withBaseUrl(item.thumbnail) : "";
}

function presetThumbnailUrl(preset: GenerateCameraPreset) {
  return preset.thumbnail && !brokenThumbnails.value[preset.id] ? withBaseUrl(preset.thumbnail) : "";
}

function markPresetThumbnailBroken(presetId: string) {
  brokenThumbnails.value = { ...brokenThumbnails.value, [presetId]: true };
}
</script>

<template>
  <div class="generate-camera-picker">
    <a-tooltip :title="hasSelection ? selectedLabel : '摄像机参数'">
      <button
        type="button"
        class="generate-camera-trigger"
        :class="{ open: open, active: hasSelection }"
        aria-label="摄像机参数"
        @click="openDialog"
      >
        <svg class="generate-camera-trigger-icon" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="12" cy="13" r="4.2" />
          <circle cx="12" cy="13" r="1.6" />
          <path d="M4.5 8.2h3.1l1.2-1.8h6.4l1.2 1.8h3.1c.9 0 1.6.7 1.6 1.6v8.1c0 .9-.7 1.6-1.6 1.6H4.5c-.9 0-1.6-.7-1.6-1.6V9.8c0-.9.7-1.6 1.6-1.6Z" />
        </svg>
      </button>
    </a-tooltip>

    <a-modal
      :open="open"
      centered
      :width="920"
      wrap-class-name="generate-camera-modal"
      @update:open="(value: boolean) => { if (!value) closeDialog(); }"
      @cancel="closeDialog"
    >
      <template #title>
        <div class="camera-dialog-title">
          <span class="camera-dialog-title-text">摄像机参数</span>
          <span class="camera-dialog-title-hint">可先调上面四列，或点下方预设一键套用</span>
        </div>
      </template>

      <div class="camera-dialog">
        <div class="camera-wheels">
        <section
          v-for="category in generateCameraCategories"
          :key="category.id"
          class="camera-column"
          @wheel.prevent="handleWheel(category.id, $event)"
        >
          <h4 class="camera-column-title">{{ category.name }}</h4>
          <button type="button" class="camera-nav" aria-label="上一项" @click="step(category.id, -1)">
            <UpOutlined />
          </button>
          <div class="camera-wheel">
            <button
              type="button"
              class="camera-wheel-item is-prev"
              :disabled="!neighborItem(category.id, -1)"
              @click="neighborItem(category.id, -1) && selectItem(category.id, neighborItem(category.id, -1)!)"
            >
              <span v-if="category.id === 'focal'" class="camera-wheel-number">
                {{ neighborItem(category.id, -1)?.name.replace('mm', '') || '' }}
              </span>
              <span v-else class="camera-wheel-ghost">{{ displayName(neighborItem(category.id, -1), "") }}</span>
            </button>
            <button
              type="button"
              class="camera-wheel-item is-current"
              :class="{ 'is-empty': !currentId(category.id) }"
              @click="currentId(category.id) && selectItem(category.id, neighborItem(category.id, 0)!)"
            >
              <span
                v-if="thumbnailUrl(neighborItem(category.id, 0))"
                class="camera-wheel-photo-wrap"
              >
                <img
                  :src="thumbnailUrl(neighborItem(category.id, 0))"
                  :alt="displayName(neighborItem(category.id, 0))"
                  class="camera-wheel-photo"
                />
              </span>
              <svg
                v-else-if="category.id === 'aperture'"
                class="camera-wheel-iris"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <circle cx="32" cy="32" r="28" />
                <circle
                  class="camera-wheel-iris-opening"
                  cx="32"
                  cy="32"
                  :r="neighborItem(category.id, 0) ? apertureOpeningRadius(neighborItem(category.id, 0)?.name) : 10"
                />
                <path d="M32 6l8 16H24L32 6Zm18 8 2 17-16-7 14-10ZM14 14l16 10-17 7 1-17Zm-2 20 17-6 9 15-26-9Zm34 0L32 49l9-15 15 9Z" />
              </svg>
              <svg v-else-if="category.id === 'body'" class="camera-wheel-icon" viewBox="0 0 64 40" aria-hidden="true">
                <rect x="6" y="12" width="36" height="20" rx="3" />
                <rect x="12" y="8" width="10" height="5" rx="1" />
                <circle cx="48" cy="22" r="10" />
                <circle cx="48" cy="22" r="5" />
              </svg>
              <svg v-else-if="category.id === 'lens'" class="camera-wheel-icon" viewBox="0 0 64 40" aria-hidden="true">
                <rect x="8" y="14" width="22" height="12" rx="2" />
                <path d="M30 12h18l6 8-6 8H30V12Z" />
                <circle cx="22" cy="20" r="4" />
              </svg>
              <span v-if="category.id === 'focal'" class="camera-wheel-number is-main">
                {{ currentId(category.id) ? neighborItem(category.id, 0)?.name.replace('mm', '') : "—" }}
              </span>
              <span class="camera-wheel-name">
                {{ category.id === 'focal' && currentId(category.id) ? 'mm' : displayName(neighborItem(category.id, 0)) }}
              </span>
            </button>
            <button
              type="button"
              class="camera-wheel-item is-next"
              :disabled="!neighborItem(category.id, 1)"
              @click="neighborItem(category.id, 1) && selectItem(category.id, neighborItem(category.id, 1)!)"
            >
              <span v-if="category.id === 'focal'" class="camera-wheel-number">
                {{ neighborItem(category.id, 1)?.name.replace('mm', '') || '' }}
              </span>
              <span v-else class="camera-wheel-ghost">{{ displayName(neighborItem(category.id, 1), "") }}</span>
            </button>
          </div>
          <button type="button" class="camera-nav" aria-label="下一项" @click="step(category.id, 1)">
            <DownOutlined />
          </button>
        </section>
        </div>

        <div v-if="generateCameraPresetGroups.length" class="camera-preset-stack">
          <section
            v-for="group in generateCameraPresetGroups"
            :key="group.name"
            class="camera-preset-panel"
          >
            <h4 class="camera-preset-title">{{ group.name }}</h4>
            <div class="camera-preset-grid">
              <button
                v-for="preset in group.presets"
                :key="preset.id"
                type="button"
                class="camera-preset-card"
                :class="{ 'is-active': activePresetId === preset.id }"
                :aria-pressed="activePresetId === preset.id"
                @click="applyPreset(preset)"
              >
                <span class="camera-preset-preview">
                  <img
                    v-if="presetThumbnailUrl(preset)"
                    :src="presetThumbnailUrl(preset)"
                    :alt="preset.name"
                    class="camera-preset-photo"
                    @error="markPresetThumbnailBroken(preset.id)"
                  />
                  <span v-if="activePresetId === preset.id" class="camera-preset-check" aria-hidden="true">
                    <CheckOutlined />
                  </span>
                </span>
                <span class="camera-preset-name">{{ preset.name }}</span>
                <span class="camera-preset-meta">{{ formatGenerateCameraPresetMeta(preset) }}</span>
              </button>
            </div>
          </section>
        </div>
      </div>

      <template #footer>
        <div class="camera-dialog-footer">
          <div class="camera-dialog-footer-actions">
            <a-button @click="closeDialog">取消</a-button>
            <a-button type="primary" @click="confirmSelection">应用</a-button>
          </div>
        </div>
      </template>
    </a-modal>
  </div>
</template>

<style scoped lang="scss">
.generate-camera-picker {
  display: inline-flex;
  flex-shrink: 0;
}

.generate-camera-trigger {
  appearance: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  padding: 0;
  border: 1px solid var(--theme-control-border-strong);
  border-radius: 12px;
  background: var(--theme-control-bg);
  color: var(--theme-title);
  cursor: pointer;
  transition:
    transform var(--motion-duration-press) var(--motion-ease-soft),
    background var(--motion-duration-fast) var(--motion-ease-soft),
    border-color var(--motion-duration-fast) var(--motion-ease-soft),
    color var(--motion-duration-fast) var(--motion-ease-soft);

  &:hover,
  &.open {
    background: var(--theme-control-hover-bg);
    border-color: var(--theme-border-strong);
    transform: translateY(-1px);
  }

  &:active {
    transform: scale(0.97);
  }

  &.active {
    color: var(--theme-accent-text, var(--theme-title));
    background: color-mix(in srgb, var(--theme-accent) 28%, var(--theme-control-bg));
    border-color: var(--theme-border-accent, var(--theme-accent));
  }

  &.active:hover,
  &.active.open {
    background: color-mix(in srgb, var(--theme-accent) 38%, var(--theme-control-bg));
    border-color: var(--theme-border-accent, var(--theme-accent));
  }
}

.generate-camera-trigger-icon {
  width: 18px;
  height: 18px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.6;
  stroke-linejoin: round;
}

html:is([data-theme="dark"], [data-theme="midnight"]) .generate-camera-trigger {
  color: var(--text-secondary);
  background: var(--theme-panel-bg-soft);
  border: 1px solid var(--theme-panel-border);

  &:hover,
  &.open {
    color: var(--theme-title);
    background: var(--theme-control-hover-bg);
    border-color: var(--theme-border-strong);
  }

  &.active {
    color: var(--theme-title);
    background: color-mix(in srgb, var(--theme-accent) 34%, var(--theme-panel-bg-soft));
    border-color: var(--theme-border-accent, var(--theme-accent));
  }

  &.active:hover,
  &.active.open {
    background: color-mix(in srgb, var(--theme-accent) 44%, var(--theme-panel-bg-soft));
  }
}

.camera-dialog-title {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 8px 10px;
  padding-right: 8px;
}

.camera-dialog-title-text {
  color: var(--theme-title);
  font-size: 16px;
  font-weight: 600;
  line-height: 1.3;
}

.camera-dialog-title-hint {
  color: var(--theme-text-secondary, rgba(0, 0, 0, 0.45));
  font-size: 12px;
  font-weight: 400;
  line-height: 1.3;
}

.camera-dialog {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.camera-preset-stack {
  position: relative;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px 24px;
  padding-top: 14px;
  border-top: 1px solid var(--theme-panel-border, rgba(0, 0, 0, 0.08));
}

.camera-preset-stack::before {
  content: "";
  position: absolute;
  top: 14px;
  bottom: 0;
  left: 50%;
  width: 1px;
  background: var(--theme-panel-border, rgba(0, 0, 0, 0.1));
  transform: translateX(-50%);
  pointer-events: none;
}

.camera-preset-title,
.camera-column-title {
  margin: 0 0 6px;
  color: var(--theme-title);
  font-size: 14px;
  font-weight: 700;
}

.camera-preset-title {
  margin-bottom: 10px;
  font-size: 15px;
}

.camera-preset-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
}

.camera-preset-card {
  appearance: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  min-width: 0;
  padding: 4px 4px 8px;
  border: 1px solid transparent;
  border-radius: 12px;
  background: transparent;
  color: inherit;
  text-align: center;
  cursor: pointer;

  &:hover {
    background: var(--theme-control-hover-bg, rgba(0, 0, 0, 0.04));
    border-color: var(--theme-border-strong, rgba(0, 0, 0, 0.16));
  }

  &.is-active {
    background: color-mix(in srgb, var(--theme-accent) 12%, transparent);
    border-color: var(--theme-border-accent, var(--theme-accent));
    box-shadow: 0 0 0 1px var(--theme-border-accent, var(--theme-accent));

    .camera-preset-name {
      color: var(--theme-accent, var(--theme-title));
      font-weight: 700;
    }
  }
}

.camera-preset-preview {
  position: relative;
  display: block;
  width: 100%;
  aspect-ratio: 1;
  overflow: hidden;
  border-radius: 8px;
  background: var(--theme-control-hover-bg, rgba(0, 0, 0, 0.04));
}

.camera-preset-photo {
  position: absolute;
  inset: 0;
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.camera-preset-check {
  position: absolute;
  top: 5px;
  right: 5px;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: var(--theme-accent, #1677ff);
  color: #fff;
  font-size: 9px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.28);
}

.camera-preset-name {
  max-width: 100%;
  overflow: hidden;
  color: var(--theme-title);
  font-size: 12px;
  font-weight: 600;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.camera-preset-meta {
  color: var(--theme-text-secondary, rgba(0, 0, 0, 0.45));
  font-size: 11px;
  font-weight: 500;
  line-height: 1.2;
}

.camera-wheels {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0;
}

.camera-column {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 0;
  padding: 0 10px;
  border-right: 1px solid var(--theme-panel-border, rgba(0, 0, 0, 0.08));

  &:last-child {
    border-right: none;
  }
}

.camera-nav {
  appearance: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  padding: 0;
  border: none;
  border-radius: 8px;
  background: transparent;
  color: var(--theme-text-secondary, rgba(0, 0, 0, 0.4));
  cursor: pointer;

  &:hover {
    color: var(--theme-title);
    background: var(--theme-control-hover-bg);
  }
}

.camera-wheel {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
  min-height: 128px;
  gap: 2px;
}

.camera-wheel-item {
  appearance: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
  min-height: 24px;
  padding: 1px 6px;
  border: none;
  border-radius: 12px;
  background: transparent;
  color: inherit;
  cursor: pointer;

  &:disabled {
    cursor: default;
    opacity: 0;
  }

  &.is-prev,
  &.is-next {
    opacity: 0.35;
  }

  &.is-current {
    min-height: 88px;
    background: var(--theme-control-hover-bg, rgba(0, 0, 0, 0.04));
    box-shadow: inset 0 0 0 1px var(--theme-panel-border, rgba(0, 0, 0, 0.06));
  }

  &.is-empty {
    opacity: 0.7;
  }
}

.camera-wheel-photo-wrap {
  display: block;
  box-sizing: border-box;
  width: 52px;
  height: 52px;
  margin-bottom: 2px;
  overflow: hidden;
  border-radius: 10px;
}

.camera-wheel-photo {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
  pointer-events: none;
}

.camera-wheel-iris {
  width: 32px;
  height: 32px;
  margin-bottom: 2px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linejoin: round;
  color: var(--theme-title);
}

.camera-wheel-iris-opening {
  fill: currentColor;
  stroke: none;
  opacity: 0.18;
}

.camera-wheel-icon {
  width: 36px;
  height: 22px;
  margin-bottom: 2px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linejoin: round;
  color: var(--theme-title);
}

.camera-wheel-number {
  color: var(--theme-text-secondary, rgba(0, 0, 0, 0.45));
  font-size: 13px;
  font-weight: 600;
  line-height: 1;

  &.is-main {
    color: var(--theme-title);
    font-size: 28px;
    font-weight: 700;
    letter-spacing: -0.04em;
  }
}

.camera-wheel-name,
.camera-wheel-ghost {
  max-width: 100%;
  overflow: hidden;
  color: var(--theme-title);
  font-size: 12px;
  font-weight: 600;
  line-height: 1.3;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.camera-wheel-ghost {
  color: var(--theme-text-secondary, rgba(0, 0, 0, 0.4));
  font-weight: 500;
}

.camera-dialog-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
}

.camera-dialog-footer-actions {
  display: flex;
  gap: 8px;
}

@media (max-width: 767px) {
  .camera-preset-stack,
  .camera-preset-grid {
    grid-template-columns: 1fr 1fr;
  }

  .camera-preset-stack::before {
    display: none;
  }

  .camera-wheels {
    grid-template-columns: 1fr 1fr;
    gap: 16px 0;
  }

  .camera-column:nth-child(2) {
    border-right: none;
  }

  .camera-dialog-footer {
    flex-direction: column;
    align-items: stretch;
  }

  .camera-dialog-footer-actions {
    justify-content: flex-end;
  }
}
</style>

<style lang="scss">
.generate-camera-modal .ant-modal-body {
  max-height: min(84vh, 820px);
  overflow: auto;
}
</style>
