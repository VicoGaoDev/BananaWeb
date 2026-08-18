<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import TutorialDocFrame from "@/components/tutorial/TutorialDocFrame.vue";
import {
  isTutorialDockTabEnabled,
  setTutorialDockTabEnabled,
} from "@/lib/generateTutorialDock";
import {
  DEFAULT_TUTORIAL_MODULE,
  isTutorialModule,
  resolveTutorialModule,
  tutorialModuleMeta,
  type TutorialModule,
} from "@/lib/tutorial";

const route = useRoute();
const router = useRouter();
const dockTabEnabled = ref(isTutorialDockTabEnabled());

const currentModule = computed(() => resolveTutorialModule(String(route.params.module || "")));
const currentSectionId = computed(() => decodeURIComponent(String(route.hash || "").replace(/^#/, "")));

function goModule(module: TutorialModule) {
  if (module === currentModule.value) return;
  void router.push(tutorialModuleMeta[module].path);
}

function goSection(id: string) {
  const nextHash = id ? `#${id}` : "";
  if (route.hash === nextHash) return;
  void router.replace({ hash: nextHash });
}

function handleDockTabEnabledChange(enabled: boolean) {
  dockTabEnabled.value = enabled;
  setTutorialDockTabEnabled(enabled);
}

watch(
  () => route.params.module,
  (module) => {
    if (!isTutorialModule(String(module || ""))) {
      void router.replace(tutorialModuleMeta[DEFAULT_TUTORIAL_MODULE].path);
    }
  },
  { immediate: true },
);
</script>

<template>
  <div class="tutorial-page">
    <label class="tutorial-dock-switch">
      <span>在创作页显示侧边教程入口</span>
      <a-switch
        class="warm-switch"
        :checked="dockTabEnabled"
        size="small"
        @change="handleDockTabEnabledChange"
      />
    </label>
    <TutorialDocFrame
      :module="currentModule"
      :section-id="currentSectionId"
      @update:module="goModule"
      @update:section="goSection"
    />
  </div>
</template>

<style scoped>
.tutorial-page {
  position: relative;
  display: flex;
  flex-direction: column;
  height: calc(100dvh - 50px);
  min-height: 560px;
  background: var(--theme-page-base, #fffaf3);
}

.tutorial-dock-switch {
  position: absolute;
  top: 12px;
  right: 16px;
  z-index: 3;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  max-width: calc(100% - 32px);
  padding: 6px 10px;
  border: 1px solid var(--theme-panel-border, rgba(80, 52, 20, 0.08));
  border-radius: 999px;
  background: color-mix(in srgb, var(--theme-panel-bg, #fffdf8) 92%, transparent);
  box-shadow: 0 6px 16px rgba(80, 52, 20, 0.08);
  color: var(--theme-text-secondary, #8b7457);
  font-size: 12px;
  line-height: 1.2;
  cursor: pointer;
}

.tutorial-dock-switch span {
  white-space: nowrap;
}
</style>
