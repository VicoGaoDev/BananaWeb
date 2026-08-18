<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, reactive, ref, watch } from "vue";
import { withBaseUrl } from "@/lib/assets";
import {
  generateTutorialSections,
  tutorialModuleMeta,
  tutorialNavOrder,
  type TutorialModule,
} from "@/lib/tutorial";

const props = defineProps<{
  module: TutorialModule;
  sectionId?: string;
}>();

const emit = defineEmits<{
  "update:module": [value: TutorialModule];
  "update:section": [value: string];
}>();

const iframeRef = ref<HTMLIFrameElement | null>(null);
const navCollapsed = ref(false);
const activeSectionId = ref(props.sectionId || "overview");
const pendingSectionId = ref("");
const preview = ref<{ src: string; alt: string; caption: string } | null>(null);
const openGroups = reactive<Record<TutorialModule, boolean>>({
  chat: false,
  generate: true,
  video: false,
  canvas: false,
});

const currentMeta = computed(() => tutorialModuleMeta[props.module]);
const tutorialSrc = computed(() => withBaseUrl(currentMeta.value.doc));

function closePreview() {
  preview.value = null;
}

function setNavCollapsed(collapsed: boolean) {
  navCollapsed.value = collapsed;
  try {
    localStorage.setItem("tutorial-nav-collapsed", collapsed ? "1" : "0");
  } catch {
    /* ignore */
  }
}

function toggleNavCollapsed() {
  setNavCollapsed(!navCollapsed.value);
}

function toggleGroup(module: TutorialModule) {
  openGroups[module] = !openGroups[module];
}

function selectModule(module: TutorialModule) {
  if (props.module === module) {
    toggleGroup(module);
    return;
  }
  openGroups[module] = true;
  emit("update:module", module);
}

function scrollToSection(id: string) {
  if (!id) return;
  activeSectionId.value = id;
  const frameWindow = iframeRef.value?.contentWindow;
  if (!frameWindow) return;
  try {
    frameWindow.postMessage({ type: "banana-tutorial-scroll", id }, window.location.origin);
  } catch {
    frameWindow.location.hash = id;
  }
}

function openGenerateSection(id: string) {
  if (props.module !== "generate") {
    pendingSectionId.value = id;
    openGroups.generate = true;
    emit("update:module", "generate");
    emit("update:section", id);
    return;
  }
  scrollToSection(id);
  emit("update:section", id);
}

function handleFrameLoad() {
  const id = pendingSectionId.value || props.sectionId;
  pendingSectionId.value = "";
  if (props.module === "generate" && id) {
    window.setTimeout(() => scrollToSection(id), 80);
  }
}

function handleFrameMessage(event: MessageEvent) {
  if (event.origin !== window.location.origin) return;
  if (event.source !== iframeRef.value?.contentWindow) return;
  const data = event.data;
  if (!data || typeof data !== "object") return;
  if (data.type === "banana-tutorial-preview" && typeof data.src === "string" && data.src) {
    preview.value = {
      src: data.src,
      alt: typeof data.alt === "string" ? data.alt : "",
      caption: typeof data.caption === "string" ? data.caption : "",
    };
    return;
  }
  if (typeof data.id !== "string") return;
  if (data.type === "banana-tutorial-section") {
    activeSectionId.value = data.id;
    return;
  }
  if (data.type === "banana-tutorial-hash") {
    activeSectionId.value = data.id;
    emit("update:section", data.id);
  }
}

function handlePreviewKeydown(event: KeyboardEvent) {
  if (event.key !== "Escape" || !preview.value) return;
  event.preventDefault();
  event.stopImmediatePropagation();
  closePreview();
}

watch(preview, (value) => {
  document.body.classList.toggle("tutorial-shot-lightbox-open", Boolean(value));
});

watch(
  () => props.module,
  (module) => {
    openGroups[module] = true;
    activeSectionId.value = props.sectionId || (module === "generate" ? "overview" : module);
    closePreview();
  },
);

watch(
  () => props.sectionId,
  (id) => {
    if (id) scrollToSection(id);
  },
);

onMounted(() => {
  try {
    navCollapsed.value = localStorage.getItem("tutorial-nav-collapsed") === "1";
  } catch {
    /* ignore */
  }
  window.addEventListener("message", handleFrameMessage);
  window.addEventListener("keydown", handlePreviewKeydown, true);
});

onBeforeUnmount(() => {
  window.removeEventListener("message", handleFrameMessage);
  window.removeEventListener("keydown", handlePreviewKeydown, true);
  closePreview();
});
</script>

<template>
  <div class="tutorial-shell" :class="{ 'is-nav-collapsed': navCollapsed }">
    <nav class="tutorial-nav" aria-label="标题导航">
      <div class="tutorial-nav-head">
        <div class="tutorial-nav-title">目录</div>
        <button
          type="button"
          class="nav-toggle"
          :aria-label="navCollapsed ? '展开目录' : '收起目录'"
          @click="toggleNavCollapsed"
        >
          <span class="nav-toggle-icon" aria-hidden="true"></span>
        </button>
      </div>

      <div
        v-for="item in tutorialNavOrder"
        :key="item"
        class="nav-group"
        :class="{ 'is-open': openGroups[item] }"
      >
        <button
          type="button"
          class="nav-group-title"
          :class="{
            'is-current': module === item,
            'is-placeholder': tutorialModuleMeta[item].placeholder,
          }"
          :aria-expanded="openGroups[item]"
          @click="selectModule(item)"
        >
          {{ tutorialModuleMeta[item].label }}
        </button>
        <div class="nav-group-children">
          <div class="nav-group-children-inner">
            <template v-if="item === 'generate'">
              <button
                v-for="section in generateTutorialSections"
                :key="section.id"
                type="button"
                class="nav-link"
                :class="{ 'is-active': module === 'generate' && activeSectionId === section.id }"
                @click="openGenerateSection(section.id)"
              >
                {{ section.label }}
              </button>
            </template>
            <span v-else class="nav-link is-soon">内容即将补充</span>
          </div>
        </div>
      </div>
    </nav>

    <div class="tutorial-main">
      <iframe
        ref="iframeRef"
        class="tutorial-frame"
        :src="tutorialSrc"
        :title="currentMeta.label + '教程'"
        @load="handleFrameLoad"
      />
    </div>

    <Teleport to="body">
      <div
        v-if="preview"
        class="tutorial-shot-lightbox"
        role="dialog"
        aria-modal="true"
        :aria-label="preview.caption || preview.alt || '图片预览'"
        @click.self="closePreview"
      >
        <button type="button" class="tutorial-shot-lightbox-close" aria-label="关闭预览" @click="closePreview"></button>
        <figure class="tutorial-shot-lightbox-figure" @click.stop>
          <img class="tutorial-shot-lightbox-image" :src="preview.src" :alt="preview.alt" />
          <figcaption v-if="preview.caption" class="tutorial-shot-lightbox-caption">{{ preview.caption }}</figcaption>
        </figure>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.tutorial-shell {
  display: flex;
  align-items: stretch;
  height: 100%;
  min-height: 0;
  background: var(--theme-page-base, #fffaf3);
}

.tutorial-nav {
  position: relative;
  z-index: 2;
  flex: 0 0 220px;
  width: 220px;
  height: 100%;
  padding: 16px 12px 28px;
  overflow: hidden auto;
  border-right: 1px solid var(--theme-panel-border, rgba(80, 52, 20, 0.08));
  background: var(--theme-panel-bg, #fffdf8);
  transition: flex-basis 0.22s ease, width 0.22s ease, padding 0.22s ease;
}

.tutorial-nav-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin: 0 4px 12px;
}

.tutorial-nav-title {
  color: var(--theme-title, #3d2f22);
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 0.04em;
}

.nav-toggle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: var(--theme-text-secondary, #8b7457);
  cursor: pointer;
}

.nav-toggle:hover {
  background: rgba(255, 171, 36, 0.16);
  color: var(--theme-title, #3d2f22);
}

.nav-toggle-icon {
  width: 7px;
  height: 7px;
  border-left: 1.6px solid currentColor;
  border-bottom: 1.6px solid currentColor;
  transform: rotate(45deg);
}

.tutorial-shell.is-nav-collapsed .tutorial-nav {
  flex-basis: 44px;
  width: 44px;
  padding: 12px 6px;
}

.tutorial-shell.is-nav-collapsed .tutorial-nav-head {
  margin: 0;
  justify-content: center;
}

.tutorial-shell.is-nav-collapsed .tutorial-nav-title,
.tutorial-shell.is-nav-collapsed .nav-group {
  display: none;
}

.tutorial-shell.is-nav-collapsed .nav-toggle-icon {
  transform: rotate(-135deg);
}

.nav-group + .nav-group {
  margin-top: 6px;
}

.nav-group-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 8px 10px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--theme-title, #3d2f22);
  font-size: 14px;
  font-weight: 700;
  text-align: left;
  cursor: pointer;
}

.nav-group-title:hover,
.nav-group-title.is-current {
  background: rgba(255, 171, 36, 0.12);
}

.nav-group-title::after {
  content: "";
  width: 6px;
  height: 6px;
  margin-left: 8px;
  border-right: 1.5px solid var(--theme-text-secondary, #8b7457);
  border-bottom: 1.5px solid var(--theme-text-secondary, #8b7457);
  transform: rotate(-45deg);
  transition: transform 0.18s ease;
}

.nav-group.is-open .nav-group-title::after {
  transform: rotate(45deg);
}

.nav-group-title.is-placeholder {
  color: var(--theme-text-secondary, #8b7457);
  font-weight: 600;
}

.nav-group-children {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows 0.2s ease, padding 0.2s ease;
}

.nav-group-children-inner {
  overflow: hidden;
  min-height: 0;
}

.nav-group.is-open .nav-group-children {
  grid-template-rows: 1fr;
  padding: 2px 0 6px;
}

.nav-link {
  display: block;
  width: 100%;
  padding: 8px 10px 8px 18px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--theme-text-secondary, #8b7457);
  text-align: left;
  text-decoration: none;
  font-size: 13px;
  line-height: 1.4;
  cursor: pointer;
}

.nav-link:hover {
  background: rgba(255, 171, 36, 0.12);
  color: var(--theme-title, #3d2f22);
}

.nav-link.is-active {
  background: rgba(255, 171, 36, 0.2);
  color: var(--theme-title, #3d2f22);
  font-weight: 700;
}

.nav-link.is-soon {
  color: #c2b09a;
  cursor: default;
}

.tutorial-main {
  flex: 1;
  min-width: 0;
  min-height: 0;
}

.tutorial-frame {
  display: block;
  width: 100%;
  height: 100%;
  border: 0;
  background: var(--theme-page-base, #fffaf3);
}
</style>

<style>
body.tutorial-shot-lightbox-open {
  overflow: hidden;
}

.tutorial-shot-lightbox {
  position: fixed;
  inset: 0;
  z-index: 4000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 28px 20px;
  background: rgba(32, 22, 12, 0.78);
  cursor: zoom-out;
}

.tutorial-shot-lightbox-figure {
  margin: 0;
  max-width: min(1200px, 100%);
  max-height: 100%;
  cursor: default;
}

.tutorial-shot-lightbox-image {
  display: block;
  max-width: 100%;
  max-height: calc(100dvh - 96px);
  border: 0;
  border-radius: 12px;
  background: #fffdf8;
  box-shadow: 0 18px 48px rgba(20, 12, 6, 0.28);
  object-fit: contain;
}

.tutorial-shot-lightbox-caption {
  margin-top: 10px;
  color: #f6ead6;
  font-size: 13px;
  text-align: center;
}

.tutorial-shot-lightbox-close {
  position: absolute;
  top: 16px;
  right: 16px;
  width: 36px;
  height: 36px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: rgba(255, 253, 248, 0.16);
  color: #fffdf8;
  cursor: pointer;
}

.tutorial-shot-lightbox-close::before,
.tutorial-shot-lightbox-close::after {
  content: "";
  position: absolute;
  top: 50%;
  left: 50%;
  width: 16px;
  height: 1.6px;
  background: currentColor;
}

.tutorial-shot-lightbox-close::before {
  transform: translate(-50%, -50%) rotate(45deg);
}

.tutorial-shot-lightbox-close::after {
  transform: translate(-50%, -50%) rotate(-45deg);
}

.tutorial-shot-lightbox-close:hover {
  background: rgba(255, 253, 248, 0.28);
}
</style>
