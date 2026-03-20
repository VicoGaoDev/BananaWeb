<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { message, Modal } from "ant-design-vue";
import { PlusOutlined, BgColorsOutlined, DeleteOutlined, SaveOutlined, EditOutlined, CloseOutlined } from "@ant-design/icons-vue";
import { fetchStyles, createStyle, deleteStyle, fetchPrompts, addPrompt, updatePrompt, deletePrompt } from "@/api/styles";
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
const savingPromptId = ref<number | null>(null);
const editingPromptId = ref<number | null>(null);

const styleCols = [
  { title: "ID", dataIndex: "id", width: 70 },
  { title: "名称", dataIndex: "name" },
  { title: "描述", dataIndex: "description" },
  { title: "操作", key: "action", width: 200 },
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

function handleEditPrompt(item: StylePrompt) {
  editingPromptId.value = item.id;
}

async function handleCancelEdit() {
  if (!currentStyleId.value || !editingPromptId.value) {
    editingPromptId.value = null;
    return;
  }
  try {
    prompts.value = await fetchPrompts(currentStyleId.value);
  } finally {
    editingPromptId.value = null;
  }
}

async function handleSavePrompt(item: StylePrompt) {
  if (!currentStyleId.value) return;
  if (!item.prompt.trim()) {
    message.warning("Prompt 不能为空");
    return;
  }
  savingPromptId.value = item.id;
  try {
    const updated = await updatePrompt(currentStyleId.value, item.id, {
      prompt: item.prompt,
      negative_prompt: item.negative_prompt,
      sort_order: item.sort_order,
    });
    const index = prompts.value.findIndex((p) => p.id === item.id);
    if (index >= 0) prompts.value[index] = updated;
    editingPromptId.value = null;
    message.success("已保存");
  } catch (err: any) {
    message.error(err.response?.data?.detail || "保存失败");
  } finally {
    savingPromptId.value = null;
  }
}
</script>

<template>
  <div class="warm-page">
    <div class="warm-page-header">
      <div class="warm-page-heading">
        <div class="warm-page-icon">
          <BgColorsOutlined />
        </div>
        <div>
          <div class="warm-page-title">风格管理</div>
          <div class="warm-page-desc">维护风格封面、描述和对应的 Prompt 组合。</div>
        </div>
      </div>
      <a-button type="primary" class="warm-primary-btn" @click="styleModalOpen = true">
        <template #icon><PlusOutlined /></template>
        新增风格
      </a-button>
    </div>

    <div class="warm-card warm-table-card">
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
      :width="920"
      :body-style="{ padding: '20px 24px 24px' }"
      :header-style="{ borderBottom: '1px solid #f0f0f0' }"
    >
      <div class="prompt-list">
        <div
          v-for="item in prompts"
          :key="item.id"
          :class="['prompt-card', { editing: editingPromptId === item.id }]"
        >
          <div class="prompt-card-head">
            <div class="prompt-meta">
              <span class="prompt-index">#{{ item.sort_order }}</span>
              <span class="prompt-id">ID {{ item.id }}</span>
            </div>
            <div class="prompt-actions">
              <template v-if="editingPromptId === item.id">
                <a-input-number v-model:value="item.sort_order" :min="0" size="small" class="sort-input" />
                <a-button
                  type="primary"
                  class="warm-primary-btn prompt-action-btn prompt-save-btn"
                  size="small"
                  :loading="savingPromptId === item.id"
                  @click="handleSavePrompt(item)"
                >
                  <template #icon><SaveOutlined /></template>
                  保存
                </a-button>
                <a-button size="small" class="prompt-action-btn prompt-cancel-btn" @click="handleCancelEdit">
                  <template #icon><CloseOutlined /></template>
                  取消
                </a-button>
              </template>
              <a-button v-else size="small" class="prompt-action-btn prompt-edit-btn" @click="handleEditPrompt(item)">
                <template #icon><EditOutlined /></template>
                编辑
              </a-button>
              <a-button size="small" class="prompt-action-btn prompt-delete-btn" @click="handleDeletePrompt(item.id)">
                <template #icon><DeleteOutlined /></template>
                删除
              </a-button>
            </div>
          </div>

          <div class="prompt-grid">
            <div class="prompt-field">
              <label>正向指令</label>
              <a-textarea
                v-if="editingPromptId === item.id"
                v-model:value="item.prompt"
                :rows="5"
                placeholder="正向提示词"
                class="prompt-textarea"
              />
              <div v-else class="prompt-display">{{ item.prompt || "-" }}</div>
            </div>
            <div class="prompt-field">
              <label>反向指令</label>
              <a-textarea
                v-if="editingPromptId === item.id"
                v-model:value="item.negative_prompt"
                :rows="5"
                placeholder="反向提示词（可选）"
                class="prompt-textarea"
              />
              <div v-else class="prompt-display negative">{{ item.negative_prompt || "-" }}</div>
            </div>
          </div>
        </div>
      </div>

      <a-divider class="prompt-divider">添加新 Prompt</a-divider>

      <div class="prompt-card create-prompt-card">
        <a-form layout="vertical" class="create-prompt-form">
          <div class="prompt-grid">
            <a-form-item label="正向指令" class="prompt-form-item">
              <a-textarea
                v-model:value="newPrompt.prompt"
                :rows="5"
                placeholder="输入正向提示词"
                class="prompt-textarea"
              />
            </a-form-item>
            <a-form-item label="反向指令" class="prompt-form-item">
              <a-textarea
                v-model:value="newPrompt.negative_prompt"
                :rows="5"
                placeholder="输入反向提示词（可选）"
                class="prompt-textarea"
              />
            </a-form-item>
          </div>

          <div class="create-prompt-actions">
            <div class="create-sort-wrap">
              <span class="create-sort-label">排序</span>
              <a-input-number v-model:value="newPrompt.sort_order" :min="0" class="sort-input create-sort-input" />
            </div>
            <a-button
              type="primary"
              class="warm-primary-btn prompt-action-btn prompt-save-btn"
              :loading="addingPrompt"
              @click="handleAddPrompt"
            >
              <template #icon><PlusOutlined /></template>
              添加 Prompt
            </a-button>
          </div>
        </a-form>
      </div>
    </a-drawer>
  </div>
</template>

<style scoped lang="scss">
:deep(.ant-drawer .ant-input),
:deep(.ant-drawer .ant-input-number),
:deep(.ant-drawer .ant-input-affix-wrapper),
:deep(.ant-modal .ant-input),
:deep(.ant-modal .ant-input-number),
:deep(.ant-modal .ant-input-affix-wrapper),
:deep(.ant-modal .ant-input-textarea textarea),
:deep(.ant-drawer .ant-input-textarea textarea) {
  border-radius: 14px;
}

:deep(.ant-drawer .ant-drawer-header) {
  background: #fff9ef;
}

:deep(.ant-drawer .ant-drawer-title) {
  color: #4c341a;
  font-weight: 700;
}

:deep(.ant-drawer .ant-drawer-body) {
  background: #fffefb;
}

.prompt-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
  margin-bottom: 24px;
}

.prompt-card {
  padding: 18px;
  border: 1px solid #f1ddb7;
  border-radius: 20px;
  background: linear-gradient(180deg, #fffdf8, #fff8ef);
  box-shadow: 0 12px 26px rgba(236, 185, 88, 0.08);

  &.editing {
    border-color: #ebb55d;
    background: linear-gradient(180deg, #fff9ef, #fff3df);
    box-shadow: 0 16px 30px rgba(236, 185, 88, 0.14);
  }
}

.prompt-card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
}

.prompt-meta {
  display: flex;
  align-items: center;
  gap: 8px;
}

.prompt-index,
.prompt-id {
  display: inline-flex;
  align-items: center;
  height: 28px;
  padding: 0 10px;
  border-radius: 999px;
  background: #fff3d8;
  color: #91652b;
  font-size: 12px;
  font-weight: 700;
}

.prompt-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sort-input {
  width: 84px;
}

.prompt-action-btn {
  height: 34px;
  padding-inline: 12px;
  border-radius: 12px;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  box-shadow: none;
}

.prompt-save-btn {
  min-width: 82px;
}

:deep(.prompt-action-btn .anticon) {
  font-size: 14px;
}

:deep(.sort-input .ant-input-number-input) {
  font-size: 13px;
  font-weight: 700;
}

.prompt-edit-btn {
  border: 1px solid #f0ddbb !important;
  background: linear-gradient(180deg, #fffaf4, #fff0df) !important;
  color: #8a6530 !important;
  box-shadow: 0 8px 18px rgba(236, 185, 88, 0.12);

  &:hover,
  &:focus {
    border-color: #ebb55d !important;
    background: linear-gradient(180deg, #fff4e7, #ffe8c4) !important;
    color: #a86500 !important;
  }
}

.prompt-cancel-btn {
  border: 1px solid #ead8ba !important;
  background: #fffdf9 !important;
  color: #8a7251 !important;

  &:hover,
  &:focus {
    border-color: #d8be97 !important;
    color: #654728 !important;
  }
}

.prompt-delete-btn {
  border: 1px solid #f3c9c1 !important;
  background: linear-gradient(180deg, #fff6f4, #ffebe7) !important;
  color: #c85a49 !important;

  &:hover,
  &:focus {
    border-color: #e7a69a !important;
    background: linear-gradient(180deg, #ffefeb, #ffe0d9) !important;
    color: #b84b3b !important;
  }
}

.prompt-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.prompt-divider {
  margin: 24px 0 20px;
}

.prompt-field {
  display: flex;
  flex-direction: column;
  gap: 8px;

  label {
    color: #5e4524;
    font-size: 13px;
    font-weight: 700;
  }
}

.prompt-display {
  min-height: 148px;
  padding: 4px 2px 0;
  color: #4d3820;
  font-size: 16px;
  line-height: 1.8;
  white-space: pre-wrap;
  word-break: break-word;

  &.negative {
    color: #7b6243;
  }
}

:deep(.prompt-textarea textarea) {
  font-size: 16px;
  line-height: 1.8;
}

.create-prompt-card {
  padding: 20px;
}

.create-prompt-form {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.prompt-form-item {
  margin-bottom: 0;
}

.create-prompt-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.create-sort-wrap {
  display: flex;
  align-items: center;
  gap: 10px;
}

.create-sort-label {
  color: #5e4524;
  font-size: 13px;
  font-weight: 700;
}

.create-sort-input {
  width: 120px;
}

@media (max-width: 900px) {
  .prompt-card-head {
    flex-direction: column;
    align-items: stretch;
  }

  .prompt-actions {
    justify-content: flex-start;
  }

  .prompt-grid {
    grid-template-columns: 1fr;
  }

  .create-prompt-actions {
    flex-direction: column;
    align-items: stretch;
  }

  .create-sort-wrap {
    justify-content: space-between;
  }
}
</style>
