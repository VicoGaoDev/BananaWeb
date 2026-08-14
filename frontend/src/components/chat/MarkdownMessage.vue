<script setup lang="ts">
import { computed } from "vue";
import { renderSimpleMarkdown } from "@/lib/simpleMarkdown";

const props = defineProps<{
  content: string;
  streaming?: boolean;
}>();

const renderedHtml = computed(() => renderSimpleMarkdown(props.content));
</script>

<template>
  <div
    class="message-content md-body"
    :class="{ 'is-streaming': streaming }"
    v-html="renderedHtml"
  ></div>
</template>
