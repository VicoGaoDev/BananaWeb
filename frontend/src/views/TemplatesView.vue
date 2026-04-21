<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { message } from "ant-design-vue";
import { PictureOutlined, TagsOutlined, ThunderboltOutlined } from "@ant-design/icons-vue";
import { useRouter } from "vue-router";
import { getTemplateDetail, listTemplates, listTemplateTags } from "@/api/templates";
import { resolveImageUrl } from "@/api/images";
import type { CreativeTemplate, TemplateTag } from "@/types";

const router = useRouter();
const TEMPLATE_DRAFT_KEY = "generateDraftFromTemplate";

const page = ref(1);
const pageSize = ref(20);
const loading = ref(false);
const loadingMore = ref(false);
const total = ref(0);
const templates = ref<CreativeTemplate[]>([]);
const tags = ref<TemplateTag[]>([]);
const activeTagId = ref<number | null>(null);
const loadMoreAnchor = ref<HTMLElement | null>(null);
let loadMoreObserver: IntersectionObserver | null = null;

const detailOpen = ref(false);
const detailLoading = ref(false);
const detail = ref<CreativeTemplate | null>(null);

const activeTagName = computed(() => tags.value.find((tag) => tag.id === activeTagId.value)?.name || "全部");
const hasMoreTemplates = computed(() => templates.value.length < total.value);

async function loadTags() {
  try {
    tags.value = await listTemplateTags();
  } catch {
    // ignore
  }
}

async function loadTemplates() {
  loading.value = true;
  try {
    const res = await listTemplates(1, pageSize.value, activeTagId.value || undefined);
    templates.value = res.items;
    total.value = res.total;
    page.value = 1;
  } catch {
    message.error("获取创意模版失败");
  } finally {
    loading.value = false;
  }
}

async function loadNextTemplatePage() {
  if (loading.value || loadingMore.value || !hasMoreTemplates.value) return;
  loadingMore.value = true;
  try {
    const nextPage = page.value + 1;
    const res = await listTemplates(nextPage, pageSize.value, activeTagId.value || undefined);
    templates.value = [...templates.value, ...res.items];
    total.value = res.total;
    page.value = nextPage;
  } catch {
    message.error("加载更多创意模版失败");
  } finally {
    loadingMore.value = false;
  }
}

function setupLoadMoreObserver(target: HTMLElement | null) {
  loadMoreObserver?.disconnect();
  loadMoreObserver = null;
  if (!target) return;

  loadMoreObserver = new IntersectionObserver(
    (entries) => {
      if (entries.some((entry) => entry.isIntersecting)) void loadNextTemplatePage();
    },
    { root: null, rootMargin: "0px 0px 260px 0px", threshold: 0.01 }
  );
  loadMoreObserver.observe(target);
}

async function openDetail(id: number) {
  detailOpen.value = true;
  detailLoading.value = true;
  try {
    detail.value = await getTemplateDetail(id);
  } catch {
    message.error("获取模版详情失败");
    detailOpen.value = false;
  } finally {
    detailLoading.value = false;
  }
}

function useTemplate() {
  if (!detail.value) return;
  localStorage.setItem(
    TEMPLATE_DRAFT_KEY,
    JSON.stringify({
      model: detail.value.model,
      prompt: detail.value.prompt,
      reference_images: detail.value.reference_images,
      num_images: 1,
      size: detail.value.size,
      resolution: detail.value.resolution,
    })
  );
  detailOpen.value = false;
  router.push("/generate");
}

function selectTag(tagId: number | null) {
  activeTagId.value = tagId;
  loadTemplates();
}

onMounted(() => {
  loadTags();
  loadTemplates();
});

onBeforeUnmount(() => {
  loadMoreObserver?.disconnect();
  loadMoreObserver = null;
});

watch(loadMoreAnchor, (target) => {
  setupLoadMoreObserver(target);
});
</script>

<template>
  <div class="templates-page warm-page">
    <div class="templates-topbar">
      <div class="warm-page-heading">
        <div class="warm-page-icon templates-topbar-icon">
          <PictureOutlined />
        </div>
        <div>
          <div class="warm-page-title templates-topbar-title">创意模版</div>
          <div class="warm-page-desc">浏览灵感案例，选择喜欢的模版后再进入编辑生成。</div>
        </div>
      </div>
      <a-button type="primary" class="warm-primary-btn" @click="router.push('/generate')">
        <template #icon><ThunderboltOutlined /></template>
        自定义绘图
      </a-button>
    </div>

    <div class="tag-filter">
      <a-tag
        class="filter-tag"
        :class="{ active: activeTagId === null }"
        @click="selectTag(null)"
      >
        全部
      </a-tag>
      <a-tag
        v-for="tag in tags"
        :key="tag.id"
        class="filter-tag"
        :class="{ active: activeTagId === tag.id }"
        @click="selectTag(tag.id)"
      >
        {{ tag.name }}
      </a-tag>
    </div>

    <a-spin :spinning="loading">
      <div v-if="!templates.length && !loading" class="empty-state warm-card">
        <a-empty description="暂无创意模版" />
      </div>

      <TransitionGroup v-else name="template-card" tag="div" class="masonry">
        <div
          v-for="(item, index) in templates"
          :key="item.id"
          class="template-card"
          :style="{ '--template-card-delay': `${Math.min(index, 9) * 45}ms` }"
          @click="openDetail(item.id)"
        >
          <div class="template-cover">
            <img v-if="item.result_image" :src="resolveImageUrl(item.result_image_thumb || item.result_image)" alt="模版结果图" loading="lazy" />
            <div v-else class="template-cover-empty">暂无结果图</div>
            <div class="template-overlay">
              <div class="template-overlay-text">查看详情</div>
            </div>
          </div>
        </div>
      </TransitionGroup>
    </a-spin>

    <div v-if="loadingMore" class="templates-load-more-tip">
      <a-spin size="small" />
      <span>正在加载更多模版...</span>
    </div>
    <div v-else-if="templates.length && !hasMoreTemplates" class="templates-load-more-tip templates-load-more-tip-finished">
      已加载全部创意模版
    </div>
    <div
      v-if="templates.length && hasMoreTemplates"
      ref="loadMoreAnchor"
      class="templates-load-more-anchor"
      aria-hidden="true"
    />

    <a-modal
      v-model:open="detailOpen"
      :title="detail ? `模版详情 · ${activeTagName}` : '模版详情'"
      :footer="null"
      :width="920"
      centered
    >
      <a-spin :spinning="detailLoading">
        <div v-if="detail" :key="detail.id" class="detail-layout">
          <div class="detail-preview">
            <img v-if="detail.result_image" :src="resolveImageUrl(detail.result_image)" alt="模版结果图" />
            <div v-else class="detail-preview-empty">暂无结果图</div>
          </div>

          <div class="detail-content">
            <div class="detail-tags">
              <a-tag v-for="tag in detail.tags" :key="tag.id" class="warm-tag">
                <template #icon><TagsOutlined /></template>
                {{ tag.name }}
              </a-tag>
            </div>

            <div class="detail-block">
              <div class="detail-label">提示词</div>
              <div class="detail-prompt">{{ detail.prompt }}</div>
            </div>

            <div v-if="detail.reference_images.length" class="detail-block">
              <div class="detail-label">参考图</div>
              <div class="detail-refs">
                <img
                  v-for="(url, idx) in detail.reference_images"
                  :key="url + idx"
                  :src="resolveImageUrl(detail.reference_image_thumbs?.[idx] || url)"
                  alt="参考图"
                  loading="lazy"
                />
              </div>
            </div>

            <div class="detail-meta">
              <div v-if="detail.model" class="detail-meta-item">
                <span class="meta-label">模型</span>
                <strong>{{ detail.model }}</strong>
              </div>
              <div class="detail-meta-item">
                <span class="meta-label">宽高比</span>
                <strong>{{ detail.size }}</strong>
              </div>
              <div v-if="detail.resolution" class="detail-meta-item">
                <span class="meta-label">分辨率</span>
                <strong>{{ detail.resolution }}</strong>
              </div>
            </div>

            <div class="detail-actions">
              <a-button type="primary" class="warm-primary-btn" @click="useTemplate">
                <template #icon><ThunderboltOutlined /></template>
                使用此模版
              </a-button>
            </div>
          </div>
        </div>
      </a-spin>
    </a-modal>
  </div>
</template>

<style scoped lang="scss">
.templates-page {
  min-height: calc(100vh - 120px);
  animation: templates-page-enter var(--motion-duration-reveal) ease both;
}

@keyframes templates-page-enter {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes templates-fade-up {
  from {
    opacity: 0;
    transform: translate3d(0, 16px, 0);
  }
  to {
    opacity: 1;
    transform: translate3d(0, 0, 0);
  }
}

@keyframes templates-detail-slide-in {
  from {
    opacity: 0;
    transform: translate3d(20px, 0, 0) scale(0.985);
  }
  to {
    opacity: 1;
    transform: translate3d(0, 0, 0) scale(1);
  }
}

.templates-topbar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 8px;
  animation: templates-fade-up var(--motion-duration-reveal) var(--motion-ease-enter) 0.04s both;
}

.templates-topbar-icon {
  width: 40px;
  height: 40px;
  border-radius: 14px;
  font-size: 18px;
}

.templates-topbar-title {
  font-size: 20px;
}

.tag-filter {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  padding: 4px 0 8px;
  animation: templates-fade-up var(--motion-duration-reveal-soft) var(--motion-ease-enter) 0.12s both;
}

.filter-tag {
  cursor: pointer;
  border-radius: 999px;
  padding: 6px 12px;
  font-weight: 600;
  transition:
    transform var(--motion-duration-press) var(--motion-ease-soft),
    box-shadow var(--motion-duration-base) var(--motion-ease-soft),
    background var(--motion-duration-base) var(--motion-ease-soft),
    border-color var(--motion-duration-base) var(--motion-ease-soft),
    color var(--motion-duration-base) var(--motion-ease-soft);

  &:hover {
    transform: translateY(-1px);
    box-shadow: 0 12px 22px rgba(236, 185, 88, 0.12);
  }

  &:active {
    transform: scale(0.96);
  }

  &.active {
    color: #8a5400;
    background: linear-gradient(180deg, #fff0cc, #ffe2a9);
    border-color: #f0c46d;
    box-shadow: 0 12px 22px rgba(236, 185, 88, 0.14);
  }
}

.masonry {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 18px;
}

.template-card {
  position: relative;
  overflow: hidden;
  border-radius: 20px;
  border: 1px solid #f0dfbe;
  background: #fff8ec;
  cursor: pointer;
  transition:
    transform var(--motion-duration-hover) var(--motion-ease-enter),
    box-shadow var(--motion-duration-hover) var(--motion-ease-soft),
    border-color var(--motion-duration-hover) var(--motion-ease-soft);

  &:hover {
    transform: translateY(-6px);
    border-color: #f0c46d;
    box-shadow: 0 22px 40px rgba(236, 185, 88, 0.2);
  }

  &:active {
    transform: translateY(-2px) scale(0.992);
  }
}

.template-cover {
  position: relative;
  overflow: hidden;
  background: #fff8ec;
  aspect-ratio: 3 / 4;

  img {
    width: 100%;
    height: 100%;
    display: block;
    object-fit: cover;
    transition: transform var(--motion-duration-emphasis) var(--motion-ease-enter);
  }
}

.template-cover-empty,
.detail-preview-empty {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #a88e68;
}

.template-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(180deg, rgba(34, 25, 14, 0.08), rgba(34, 25, 14, 0.56));
  opacity: 0;
  transition: opacity var(--motion-duration-base) var(--motion-ease-soft);

  .template-card:hover & {
    opacity: 1;
  }
}

.template-card:hover .template-cover img {
  transform: scale(1.045);
}

.template-overlay-text {
  padding: 10px 18px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.92);
  color: #5d4526;
  font-size: 14px;
  font-weight: 700;
  transition: transform var(--motion-duration-swift) var(--motion-ease-soft);
}

.template-card:hover .template-overlay-text {
  transform: translateY(-2px);
}

.detail-layout {
  display: grid;
  grid-template-columns: 1.1fr 0.9fr;
  gap: 24px;
  animation: templates-detail-slide-in var(--motion-duration-reveal-slower) var(--motion-ease-enter) both;
}

.detail-preview {
  height: 560px;
  border-radius: 20px;
  overflow: hidden;
  background: #fff8ec;
  display: flex;
  align-items: center;
  justify-content: center;

  img {
    width: auto;
    height: 100%;
    max-width: 100%;
    display: block;
    object-fit: contain;
    transition: transform var(--motion-duration-hover) var(--motion-ease-soft);
  }
}

.detail-preview:hover img {
  transform: scale(1.015);
}

.detail-content {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.detail-tags {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.detail-label {
  color: #8d7457;
  font-size: 12px;
  font-weight: 700;
  margin-bottom: 8px;
}

.detail-prompt {
  padding: 14px 16px;
  border-radius: 16px;
  background: #fff8ec;
  color: #4c341a;
  line-height: 1.8;
  white-space: pre-wrap;
  word-break: break-word;
}

.detail-refs {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;

  img {
    width: 82px;
    height: 82px;
    border-radius: 12px;
    object-fit: cover;
    border: 1px solid #f0dfbe;
    transition:
      transform var(--motion-duration-swift) var(--motion-ease-soft),
      box-shadow var(--motion-duration-swift) var(--motion-ease-soft),
      border-color var(--motion-duration-swift) var(--motion-ease-soft);

    &:hover {
      transform: translateY(-2px);
      border-color: #e5bb73;
      box-shadow: 0 14px 22px rgba(236, 185, 88, 0.14);
    }
  }
}

.detail-meta {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.detail-meta-item {
  padding: 12px 14px;
  border-radius: 16px;
  background: #fff8ec;
  border: 1px solid #f0dfbe;

  strong {
    display: block;
    margin-top: 4px;
    color: #4c341a;
    font-size: 15px;
  }
}

.meta-label {
  color: #8d7457;
  font-size: 12px;
  font-weight: 600;
}

.detail-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: auto;
}

.empty-state {
  padding: 80px 0;
  animation: templates-fade-up var(--motion-duration-reveal) var(--motion-ease-enter) 0.2s both;
}

.templates-load-more-tip {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  min-height: 48px;
  margin: 18px 0 4px;
  color: #8d7457;
  font-size: 13px;
}

.templates-load-more-tip-finished {
  color: #a88e68;
}

.templates-load-more-anchor {
  width: 100%;
  height: 2px;
}

:deep(.warm-primary-btn) {
  transition:
    transform var(--motion-duration-press) var(--motion-ease-soft),
    box-shadow var(--motion-duration-base) var(--motion-ease-soft),
    background var(--motion-duration-base) var(--motion-ease-soft);
}

:deep(.warm-primary-btn:hover),
:deep(.warm-primary-btn:focus) {
  transform: translateY(-1px);
}

:deep(.warm-primary-btn:active) {
  transform: scale(0.96);
}

.template-card-enter-active,
.template-card-leave-active {
  transition:
    opacity var(--motion-duration-emphasis) var(--motion-ease-soft),
    transform var(--motion-duration-emphasis-plus) var(--motion-ease-enter);
  transition-delay: var(--template-card-delay, 0ms);
}

.template-card-enter-from,
.template-card-leave-to {
  opacity: 0;
  transform: translate3d(0, 22px, 0) scale(0.985);
}

.template-card-move {
  transition: transform var(--motion-duration-reveal-fast) var(--motion-ease-enter);
}

@media (prefers-reduced-motion: reduce) {
  .templates-page,
  .templates-topbar,
  .tag-filter,
  .empty-state,
  .detail-layout {
    animation: none !important;
  }

  .template-card,
  .template-card-enter-active,
  .template-card-leave-active,
  .template-card-move,
  .template-cover img,
  .template-overlay,
  .template-overlay-text,
  .filter-tag,
  .detail-preview img,
  .detail-refs img,
  :deep(.warm-primary-btn) {
    transition: none !important;
  }
}

@media (max-width: 1200px) {
  .masonry {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (max-width: 900px) {
  .masonry {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .detail-layout {
    grid-template-columns: 1fr;
  }

  .detail-preview {
    height: 420px;
  }
}

@media (max-width: 640px) {
  .masonry {
    grid-template-columns: 1fr;
  }

  .detail-meta {
    grid-template-columns: 1fr;
  }

  .detail-preview {
    height: 320px;
  }
}

@media (max-width: 900px) {
  .templates-topbar {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
