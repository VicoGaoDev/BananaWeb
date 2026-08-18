<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { CloseOutlined, ReadOutlined } from "@ant-design/icons-vue";
import { useRoute, useRouter } from "vue-router";
import TutorialDocFrame from "@/components/tutorial/TutorialDocFrame.vue";
import { requestCloseAiAssistantDock } from "@/lib/chatGenerateDraft";
import {
  CLOSE_GENERATE_TUTORIAL_DOCK_EVENT,
  OPEN_GENERATE_TUTORIAL_DOCK_EVENT,
} from "@/lib/generateTutorialDock";
import {
  DEFAULT_TUTORIAL_MODULE,
  resolveTutorialModule,
  tutorialModuleMeta,
  type TutorialModule,
} from "@/lib/tutorial";

const route = useRoute();
const router = useRouter();
const open = ref(false);
const tabVisible = ref(true);
const currentModule = ref<TutorialModule>(DEFAULT_TUTORIAL_MODULE);
const isTutorialPage = computed(() => route.path.startsWith("/tutorial"));
let tabRevealTimer = 0;

function syncBodyDockClass() {
  document.body.classList.toggle("generate-tutorial-dock-open", open.value);
}

function revealTab() {
  window.clearTimeout(tabRevealTimer);
  tabRevealTimer = window.setTimeout(() => {
    if (!open.value) tabVisible.value = true;
  }, 280);
}

function openDock() {
  window.clearTimeout(tabRevealTimer);
  requestCloseAiAssistantDock();
  currentModule.value = isTutorialPage.value
    ? resolveTutorialModule(String(route.params.module || ""))
    : DEFAULT_TUTORIAL_MODULE;
  tabVisible.value = false;
  open.value = true;
}

function closeDock() {
  if (!open.value) return;
  open.value = false;
  revealTab();
}

function openFullTutorial() {
  closeDock();
  void router.push(tutorialModuleMeta[currentModule.value].path);
}

function handleWindowKeydown(event: KeyboardEvent) {
  if (event.key === "Escape") closeDock();
}

watch(open, (isOpen) => {
  syncBodyDockClass();
  if (isOpen) requestCloseAiAssistantDock();
});

onMounted(() => {
  window.addEventListener("keydown", handleWindowKeydown);
  window.addEventListener(OPEN_GENERATE_TUTORIAL_DOCK_EVENT, openDock);
  window.addEventListener(CLOSE_GENERATE_TUTORIAL_DOCK_EVENT, closeDock);
});

onBeforeUnmount(() => {
  window.clearTimeout(tabRevealTimer);
  window.removeEventListener("keydown", handleWindowKeydown);
  window.removeEventListener(OPEN_GENERATE_TUTORIAL_DOCK_EVENT, openDock);
  window.removeEventListener(CLOSE_GENERATE_TUTORIAL_DOCK_EVENT, closeDock);
  document.body.classList.remove("generate-tutorial-dock-open");
});
</script>

<template>
  <button
    v-show="tabVisible"
    type="button"
    class="generate-tutorial-tab"
    aria-label="使用教程"
    @click="openDock"
  >
    <span class="generate-tutorial-tab-icon">
      <ReadOutlined />
    </span>
    <span class="generate-tutorial-tab-label">使用教程</span>
  </button>

  <aside
    class="generate-tutorial-panel"
    :class="{ 'is-open': open }"
    :aria-hidden="!open"
  >
    <header class="generate-tutorial-panel-head">
      <div class="generate-tutorial-panel-title">
        <span class="generate-tutorial-panel-icon">
          <ReadOutlined />
        </span>
        <strong>使用教程</strong>
      </div>
      <div class="generate-tutorial-panel-actions">
        <button
          v-if="!isTutorialPage"
          type="button"
          class="generate-tutorial-open-full"
          @click="openFullTutorial"
        >
          在教程页打开
        </button>
        <button type="button" class="generate-tutorial-close" aria-label="关闭" @click="closeDock">
          <CloseOutlined />
        </button>
      </div>
    </header>
    <div class="generate-tutorial-panel-body">
      <TutorialDocFrame
        v-if="open"
        :module="currentModule"
        @update:module="currentModule = $event"
      />
    </div>
  </aside>
</template>

<style scoped>
.generate-tutorial-tab {
  position: fixed;
  top: calc(50% - 86px);
  right: 0;
  z-index: 1060;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  width: 44px;
  padding: 12px 6px 14px;
  border: 1px solid rgb(255, 171, 36);
  border-right: 0;
  border-radius: 16px 0 0 16px;
  background: rgb(255, 171, 36);
  box-shadow: -6px 8px 20px rgba(255, 171, 36, 0.32);
  color: #523713;
  cursor: pointer;
  transform: translateY(-100%);
  transition:
    background 0.2s ease,
    box-shadow 0.2s ease,
    width 0.2s ease;
}

.generate-tutorial-tab:hover {
  width: 50px;
  background: rgb(240, 150, 16);
  box-shadow: -8px 10px 24px rgba(255, 171, 36, 0.42);
}

.generate-tutorial-tab-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: rgba(82, 55, 19, 0.12);
  font-size: 14px;
}

.generate-tutorial-tab-label {
  writing-mode: vertical-rl;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.12em;
  line-height: 1.1;
}

.generate-tutorial-panel {
  position: fixed;
  top: 0;
  right: 0;
  z-index: 1061;
  display: flex;
  flex-direction: column;
  box-sizing: border-box;
  width: min(720px, 100vw);
  max-width: 720px;
  height: 100dvh;
  overflow: hidden;
  background: var(--theme-page-base, #fffaf3);
  box-shadow: -12px 0 28px rgba(80, 52, 20, 0.12);
  transform: translateX(100%);
  visibility: hidden;
  pointer-events: none;
  transition: transform 0.28s ease, visibility 0s linear 0.28s;
}

.generate-tutorial-panel.is-open {
  transform: translateX(0);
  visibility: visible;
  pointer-events: auto;
  transition: transform 0.28s ease;
}

.generate-tutorial-panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-shrink: 0;
  height: 56px;
  padding: 0 16px;
  border-bottom: 1px solid var(--theme-panel-border, rgba(0, 0, 0, 0.06));
}

.generate-tutorial-panel-title {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}

.generate-tutorial-panel-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: rgb(255, 171, 36);
  color: #523713;
  font-size: 14px;
  flex-shrink: 0;
}

.generate-tutorial-panel-head strong {
  color: var(--theme-title, #3d2f22);
  font-size: 16px;
}

.generate-tutorial-panel-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.generate-tutorial-open-full {
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--theme-link, #d38a12);
  font-size: 13px;
  cursor: pointer;
}

.generate-tutorial-close {
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

.generate-tutorial-close:hover {
  background: color-mix(in srgb, var(--theme-title, #3d2f22) 8%, transparent);
  color: var(--theme-title, #3d2f22);
}

.generate-tutorial-panel-body {
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

@media (max-width: 768px) {
  .generate-tutorial-tab {
    top: auto;
    bottom: 196px;
    transform: none;
  }
}
</style>

<style>
body.generate-tutorial-dock-open .suggestion-fab-wrap {
  visibility: hidden;
  pointer-events: none;
}
</style>
