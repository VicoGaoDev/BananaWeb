<script setup lang="ts">
import { CameraOutlined, FolderOpenOutlined, PictureOutlined } from "@ant-design/icons-vue";

defineEmits<{
  camera: [];
  gallery: [];
  files: [];
  cancel: [];
}>();
</script>

<template>
  <Teleport to="body">
    <div class="image-source-sheet-mask" @click="$emit('cancel')">
      <div class="image-source-sheet" role="dialog" aria-label="选择图片来源" @click.stop>
        <div class="image-source-sheet-title">选择图片来源</div>
        <button type="button" class="image-source-sheet-item" @click="$emit('camera')">
          <CameraOutlined />
          <span>相机</span>
        </button>
        <button type="button" class="image-source-sheet-item" @click="$emit('gallery')">
          <PictureOutlined />
          <span>相册</span>
        </button>
        <button type="button" class="image-source-sheet-item" @click="$emit('files')">
          <FolderOpenOutlined />
          <span>文件管理器</span>
        </button>
        <button type="button" class="image-source-sheet-cancel" @click="$emit('cancel')">取消</button>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.image-source-sheet-mask {
  position: fixed;
  inset: 0;
  z-index: 1200;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  padding: 12px 12px calc(12px + env(safe-area-inset-bottom));
  background: rgba(0, 0, 0, 0.45);
}

.image-source-sheet {
  width: min(100%, 420px);
  overflow: hidden;
  border-radius: 16px;
  background: var(--theme-page-base);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.18);
}

.image-source-sheet-title {
  padding: 14px 16px 8px;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.4;
  text-align: center;
}

.image-source-sheet-item,
.image-source-sheet-cancel {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  min-height: 48px;
  padding: 0 16px;
  border: 0;
  background: transparent;
  color: var(--text-primary);
  font-size: 16px;
  line-height: 1.4;
}

.image-source-sheet-item + .image-source-sheet-item {
  border-top: 1px solid var(--theme-border-soft, rgba(127, 127, 127, 0.16));
}

.image-source-sheet-cancel {
  margin-top: 8px;
  border-top: 8px solid var(--theme-border-soft, rgba(127, 127, 127, 0.12));
  color: var(--text-secondary);
  font-weight: 500;
}
</style>
