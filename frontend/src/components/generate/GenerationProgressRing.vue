<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { readGenerationProgress, subscribeGenerationClock } from "@/lib/generationProgress";

const props = withDefaults(defineProps<{
  progressKey: string;
  startedAt?: string | null;
  estimateSeconds?: number | null;
  size?: number;
}>(), {
  startedAt: "",
  estimateSeconds: 60,
  size: 60,
});

const RADIUS = 42;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

const tick = ref(0);
const live = ref(false);
const localRunKey = `local-${Date.now()}-${Math.random().toString(36).slice(2)}`;
let stopClock = () => {};

const progressStateKey = computed(() => `${props.progressKey}:${props.startedAt || localRunKey}`);
const percent = computed(() => {
  tick.value;
  return readGenerationProgress(progressStateKey.value, props.startedAt, props.estimateSeconds);
});
const dashOffset = computed(() => CIRCUMFERENCE * (1 - percent.value / 100));

onMounted(() => {
  stopClock = subscribeGenerationClock(() => {
    tick.value += 1;
  });
  requestAnimationFrame(() => {
    live.value = true;
  });
});

onBeforeUnmount(() => {
  stopClock();
});
</script>

<template>
  <div
    class="generation-progress"
    :class="{ 'is-live': live }"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${Math.round(size * 0.28)}px` }"
    role="progressbar"
    :aria-valuenow="percent"
    aria-valuemin="0"
    aria-valuemax="99"
    :aria-label="`生成进度 ${percent}%`"
  >
    <svg viewBox="0 0 100 100" aria-hidden="true">
      <circle class="generation-progress-track" cx="50" cy="50" :r="RADIUS" />
      <circle
        class="generation-progress-bar"
        cx="50"
        cy="50"
        :r="RADIUS"
        :stroke-dasharray="CIRCUMFERENCE"
        :stroke-dashoffset="dashOffset"
        transform="rotate(-90 50 50)"
      />
    </svg>
    <span class="generation-progress-label">{{ percent }}%</span>
  </div>
</template>

<style scoped>
.generation-progress {
  --ring-track: color-mix(in srgb, var(--theme-title, #4c341a) 18%, transparent);
  --ring-bar: var(--theme-accent, #c4a06a);
  --ring-text: var(--theme-accent-text, var(--theme-title, #8d7758));
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex: none;
}

.generation-progress svg {
  width: 100%;
  height: 100%;
}

.generation-progress-track,
.generation-progress-bar {
  fill: none;
  stroke-width: 8;
}

.generation-progress-track {
  stroke: var(--ring-track);
}

.generation-progress-bar {
  stroke: var(--ring-bar);
  stroke-linecap: round;
}

.generation-progress.is-live .generation-progress-bar {
  transition: stroke-dashoffset 0.9s linear;
}

.generation-progress-label {
  position: absolute;
  color: var(--ring-text);
  font-size: 1em;
  font-weight: 600;
  letter-spacing: -0.03em;
  line-height: 1;
}
</style>
