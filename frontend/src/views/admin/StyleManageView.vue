<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { message, Modal } from "ant-design-vue";
import { PlusOutlined, BgColorsOutlined, DeleteOutlined } from "@ant-design/icons-vue";
import { fetchStyles, createStyle, deleteStyle, fetchPrompts, addPrompt, deletePrompt } from "@/api/styles";
import type { Style, StylePrompt } from "@/types";

const styles = ref<Style[]>([]);
const loading = ref(false);
const styleModalOpen = ref(false);
const styleCreating = ref(false);
const newStyle = reactive({ name: "", description: "", cover_image: "" });

const promptDrawerOpen = ref(false);
const currentStyleId = ref<number | null>(null);
const currentStyleName = ref("");
const prompts = ref<StylePrompt[]>([]);
const newPrompt = reactive({ prompt: "", negative_prompt: "", sort_order: 0 });
const addingPrompt = ref(false);

const styleCols = [
  { title: "ID", dataIndex: "id", width: 70 },
  { title: "名称", dataIndex: "name" },
  { title: "描述", dataIndex: "description" },
  { title: "操作", key: "action", width: 200 },
];

const promptCols = [
  { title: "#", dataIndex: "sort_order", width: 50 },
  { title: "Prompt", dataIndex: "prompt", ellipsis: true },
  { title: "Negative", dataIndex: "negative_prompt", ellipsis: true, width: 200 },
  { title: "", key: "action", width: 60 },
];

async function load() {
  loading.value = true;
  try { styles.value = await fetchStyles(); }
  catch { message.error("获取风格列表失败"); }
  finally { loading.value = false; }
}
onMounted(load);

async function handleCreateStyle() {
  if (!newStyle.name) { message.warning("请填写风格名称"); return; }
  styleCreating.value = true;
  try {
    await createStyle({ ...newStyle });
    message.success("创建成功");
    styleModalOpen.value = false;
    newStyle.name = ""; newStyle.description = ""; newStyle.cover_image = "";
    load();
  } catch (err: any) { message.error(err.response?.data?.detail || "创建失败"); }
  finally { styleCreating.value = false; }
}

function handleDeleteStyle(s: Style) {
  Modal.confirm({
    title: `确认删除风格 "${s.name}" ？`,
    content: "关联的 Prompt 也会一并删除",
    centered: true,
    okType: "danger" as const,
    async onOk() {
      await deleteStyle(s.id);
      message.success("删除成功");
      load();
    },
  });
}

async function openPromptDrawer(s: Style) {
  currentStyleId.value = s.id;
  currentStyleName.value = s.name;
  promptDrawerOpen.value = true;
  try { prompts.value = await fetchPrompts(s.id); }
  catch { message.error("获取 Prompt 失败"); }
}

async function handleAddPrompt() {
  if (!newPrompt.prompt || !currentStyleId.value) { message.warning("请填写 Prompt"); return; }
  addingPrompt.value = true;
  try {
    await addPrompt(currentStyleId.value, { ...newPrompt });
    message.success("添加成功");
    newPrompt.prompt = ""; newPrompt.negative_prompt = ""; newPrompt.sort_order = 0;
    prompts.value = await fetchPrompts(currentStyleId.value);
  } catch (err: any) { message.error(err.response?.data?.detail || "添加失败"); }
  finally { addingPrompt.value = false; }
}

async function handleDeletePrompt(pid: number) {
  if (!currentStyleId.value) return;
  await deletePrompt(currentStyleId.value, pid);
  message.success("已删除");
  prompts.value = await fetchPrompts(currentStyleId.value);
}
</script>

<template>
  <div>
    <div class="page-header">
      <h2 class="page-title">
        <BgColorsOutlined style="margin-right: 8px" />
        风格管理
      </h2>
      <a-button type="primary" @click="styleModalOpen = true">
        <template #icon><PlusOutlined /></template>
        新增风格
      </a-button>
    </div>

    <div class="dashboard-card" style="padding: 0; overflow: hidden">
      <a-table :columns="styleCols" :data-source="styles" :loading="loading" row-key="id" :pagination="false">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'action'">
            <a-button type="link" size="small" @click="openPromptDrawer(record)">管理 Prompt</a-button>
            <a-divider type="vertical" />
            <a-button type="link" size="small" danger @click="handleDeleteStyle(record)">删除</a-button>
          </template>
        </template>
      </a-table>
    </div>

    <!-- Create style modal -->
    <a-modal
      v-model:open="styleModalOpen"
      title="新增风格"
      :confirm-loading="styleCreating"
      ok-text="创建"
      cancel-text="取消"
      centered
      :width="480"
      @ok="handleCreateStyle"
    >
      <a-form layout="vertical" style="margin-top: 16px">
        <a-form-item label="名称">
          <a-input v-model:value="newStyle.name" placeholder="如：赛博朋克" />
        </a-form-item>
        <a-form-item label="描述">
          <a-input v-model:value="newStyle.description" placeholder="简要描述" />
        </a-form-item>
        <a-form-item label="封面图 URL" style="margin-bottom: 0">
          <a-input v-model:value="newStyle.cover_image" placeholder="可选，图片链接" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Prompt management drawer -->
    <a-drawer
      v-model:open="promptDrawerOpen"
      :title="`管理 Prompt — ${currentStyleName}`"
      :width="680"
      :body-style="{ padding: '16px 24px' }"
      :header-style="{ borderBottom: '1px solid #f0f0f0' }"
    >
      <a-table :columns="promptCols" :data-source="prompts" row-key="id" :pagination="false" size="small" style="margin-bottom: 24px">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'action'">
            <a-button type="text" size="small" danger @click="handleDeletePrompt(record.id)">
              <template #icon><DeleteOutlined /></template>
            </a-button>
          </template>
        </template>
      </a-table>

      <a-divider>添加新 Prompt</a-divider>

      <a-form layout="vertical">
        <a-form-item label="Prompt">
          <a-textarea v-model:value="newPrompt.prompt" :rows="2" placeholder="正向提示词" />
        </a-form-item>
        <a-form-item label="Negative Prompt">
          <a-input v-model:value="newPrompt.negative_prompt" placeholder="反向提示词（可选）" />
        </a-form-item>
        <a-form-item label="排序">
          <a-input-number v-model:value="newPrompt.sort_order" :min="0" style="width: 120px" />
        </a-form-item>
        <a-button type="primary" :loading="addingPrompt" @click="handleAddPrompt">
          <template #icon><PlusOutlined /></template>
          添加
        </a-button>
      </a-form>
    </a-drawer>
  </div>
</template>

<style scoped lang="scss">
.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
}

.page-title {
  font-size: 20px;
  font-weight: 700;
  color: var(--text);
}
</style>
