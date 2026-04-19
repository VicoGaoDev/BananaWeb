<script setup lang="ts">
import { ref, nextTick, watch } from "vue";

const PREVIEW_MASK_COLOR = "rgba(255, 171, 37, 0.5)";
const EXPORT_MASK_COLOR = "#fff";
const EXPORT_MASK_BG = "#000";

const props = withDefaults(defineProps<{
  imageUrl: string;
  maskUrl?: string;
  brushSize?: number;
  tool?: "paint" | "erase";
}>(), {
  maskUrl: "",
  brushSize: 28,
  tool: "paint",
});

const emit = defineEmits<{
  (e: "mask-change", value: boolean): void;
}>();

const imageRef = ref<HTMLImageElement | null>(null);
const canvasRef = ref<HTMLCanvasElement | null>(null);

const exportCanvas = document.createElement("canvas");
const exportCtx = exportCanvas.getContext("2d");
const historyStack: Array<{
  view: ImageData;
  exported: ImageData;
}> = [];
const redoStack: Array<{
  view: ImageData;
  exported: ImageData;
}> = [];

const hasMask = ref(false);
let drawing = false;
let lastViewPoint: { x: number; y: number } | null = null;
let lastExportPoint: { x: number; y: number } | null = null;

function resetExportCanvas(width: number, height: number) {
  if (!exportCtx) return;
  exportCanvas.width = width;
  exportCanvas.height = height;
  exportCtx.fillStyle = EXPORT_MASK_BG;
  exportCtx.fillRect(0, 0, width, height);
}

function setupViewCanvas() {
  const image = imageRef.value;
  const canvas = canvasRef.value;
  if (!image || !canvas) return;

  const rect = image.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  canvas.width = Math.max(1, Math.round(rect.width * dpr));
  canvas.height = Math.max(1, Math.round(rect.height * dpr));
  canvas.style.width = `${rect.width}px`;
  canvas.style.height = `${rect.height}px`;

  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, rect.width, rect.height);
}

function renderPreviewFromExport() {
  const canvas = canvasRef.value;
  if (!canvas || !exportCtx || !exportCanvas.width || !exportCanvas.height) return;
  const viewCtx = canvas.getContext("2d");
  if (!viewCtx) return;

  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) return;

  const tempCanvas = document.createElement("canvas");
  tempCanvas.width = Math.max(1, Math.round(rect.width));
  tempCanvas.height = Math.max(1, Math.round(rect.height));
  const tempCtx = tempCanvas.getContext("2d");
  if (!tempCtx) return;

  tempCtx.drawImage(exportCanvas, 0, 0, tempCanvas.width, tempCanvas.height);
  const imageData = tempCtx.getImageData(0, 0, tempCanvas.width, tempCanvas.height);
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const isMasked = data[i] > 0 || data[i + 1] > 0 || data[i + 2] > 0;
    data[i] = 255;
    data[i + 1] = 171;
    data[i + 2] = 37;
    data[i + 3] = isMasked ? 128 : 0;
  }

  tempCtx.putImageData(imageData, 0, 0);
  viewCtx.clearRect(0, 0, rect.width, rect.height);
  viewCtx.drawImage(tempCanvas, 0, 0, rect.width, rect.height);
}

function loadImage(url: string): Promise<HTMLImageElement | null> {
  const resolvedUrl = (url || "").trim();
  if (!resolvedUrl) return Promise.resolve(null);
  return new Promise((resolve) => {
    const image = new Image();
    image.crossOrigin = "anonymous";
    image.onload = () => resolve(image);
    image.onerror = () => resolve(null);
    image.src = resolvedUrl;
  });
}

async function applyInitialMask() {
  if (!props.maskUrl || !exportCtx) {
    renderPreviewFromExport();
    recomputeMaskState();
    return;
  }
  const maskImage = await loadImage(props.maskUrl);
  if (!maskImage) {
    renderPreviewFromExport();
    recomputeMaskState();
    return;
  }
  exportCtx.drawImage(maskImage, 0, 0, exportCanvas.width, exportCanvas.height);
  renderPreviewFromExport();
  recomputeMaskState();
}

async function initializeCanvas() {
  const image = imageRef.value;
  const canvas = canvasRef.value;
  if (!image || !image.naturalWidth || !image.naturalHeight) return;
  setupViewCanvas();
  resetExportCanvas(image.naturalWidth, image.naturalHeight);
  const viewCtx = canvas?.getContext("2d");
  if (viewCtx && canvas) {
    viewCtx.clearRect(0, 0, canvas.width, canvas.height);
  }
  historyStack.length = 0;
  redoStack.length = 0;
  hasMask.value = false;
  emit("mask-change", false);
  await applyInitialMask();
}

async function handleImageLoad() {
  await nextTick();
  await initializeCanvas();
}

function drawLine(
  ctx: CanvasRenderingContext2D,
  from: { x: number; y: number },
  to: { x: number; y: number },
  width: number,
  color: string,
  mode: "paint" | "erase" = "paint",
) {
  ctx.save();
  ctx.globalCompositeOperation = mode === "erase" ? "destination-out" : "source-over";
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.beginPath();
  ctx.moveTo(from.x, from.y);
  ctx.lineTo(to.x, to.y);
  ctx.stroke();
  ctx.restore();
}

function recomputeMaskState() {
  if (!exportCtx || !exportCanvas.width || !exportCanvas.height) {
    hasMask.value = false;
    emit("mask-change", false);
    return;
  }
  const data = exportCtx.getImageData(0, 0, exportCanvas.width, exportCanvas.height).data;
  let filled = false;
  for (let i = 0; i < data.length; i += 4) {
    if (data[i] > 0 || data[i + 1] > 0 || data[i + 2] > 0) {
      filled = true;
      break;
    }
  }
  hasMask.value = filled;
  emit("mask-change", filled);
}

function pushSnapshot() {
  const canvas = canvasRef.value;
  const viewCtx = canvas?.getContext("2d");
  if (!canvas || !viewCtx || !exportCtx) return;
  historyStack.push({
    view: viewCtx.getImageData(0, 0, canvas.width, canvas.height),
    exported: exportCtx.getImageData(0, 0, exportCanvas.width, exportCanvas.height),
  });
  if (historyStack.length > 20) historyStack.shift();
  redoStack.length = 0;
}

function getPoints(event: PointerEvent) {
  const image = imageRef.value;
  const canvas = canvasRef.value;
  if (!image || !canvas) return null;

  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) return null;

  const viewPoint = {
    x: event.clientX - rect.left,
    y: event.clientY - rect.top,
  };
  const scale = image.naturalWidth / rect.width;
  const exportPoint = {
    x: viewPoint.x * scale,
    y: viewPoint.y * scale,
  };

  return { viewPoint, exportPoint, scale };
}

function handlePointerDown(event: PointerEvent) {
  const points = getPoints(event);
  const canvas = canvasRef.value;
  if (!points || !canvas || !exportCtx) return;

  drawing = true;
  canvas.setPointerCapture(event.pointerId);
  pushSnapshot();
  lastViewPoint = points.viewPoint;
  lastExportPoint = points.exportPoint;

  drawLine(
    exportCtx,
    points.exportPoint,
    points.exportPoint,
    props.brushSize * points.scale,
    props.tool === "erase" ? EXPORT_MASK_BG : EXPORT_MASK_COLOR,
    props.tool
  );

  renderPreviewFromExport();
  recomputeMaskState();
}

function handlePointerMove(event: PointerEvent) {
  if (!drawing) return;
  const points = getPoints(event);
  if (!points || !exportCtx || !lastViewPoint || !lastExportPoint) return;
  drawLine(
    exportCtx,
    lastExportPoint,
    points.exportPoint,
    props.brushSize * points.scale,
    props.tool === "erase" ? EXPORT_MASK_BG : EXPORT_MASK_COLOR,
    props.tool
  );

  lastViewPoint = points.viewPoint;
  lastExportPoint = points.exportPoint;
  renderPreviewFromExport();
}

function stopDrawing(event?: PointerEvent) {
  if (event && canvasRef.value?.hasPointerCapture(event.pointerId)) {
    canvasRef.value.releasePointerCapture(event.pointerId);
  }
  drawing = false;
  lastViewPoint = null;
  lastExportPoint = null;
}

function clearMask() {
  initializeCanvas();
}

function undo() {
  const canvas = canvasRef.value;
  const viewCtx = canvas?.getContext("2d");
  const snapshot = historyStack.pop();
  if (!canvas || !viewCtx || !exportCtx || !snapshot) return false;
  redoStack.push({
    view: viewCtx.getImageData(0, 0, canvas.width, canvas.height),
    exported: exportCtx.getImageData(0, 0, exportCanvas.width, exportCanvas.height),
  });
  viewCtx.putImageData(snapshot.view, 0, 0);
  exportCtx.putImageData(snapshot.exported, 0, 0);
  recomputeMaskState();
  return true;
}

function canUndo() {
  return historyStack.length > 0;
}

function redo() {
  const canvas = canvasRef.value;
  const viewCtx = canvas?.getContext("2d");
  const snapshot = redoStack.pop();
  if (!canvas || !viewCtx || !exportCtx || !snapshot) return false;
  historyStack.push({
    view: viewCtx.getImageData(0, 0, canvas.width, canvas.height),
    exported: exportCtx.getImageData(0, 0, exportCanvas.width, exportCanvas.height),
  });
  viewCtx.putImageData(snapshot.view, 0, 0);
  exportCtx.putImageData(snapshot.exported, 0, 0);
  recomputeMaskState();
  return true;
}

function canRedo() {
  return redoStack.length > 0;
}

function hasDrawnMask() {
  return hasMask.value;
}

function exportMaskBlob(): Promise<Blob | null> {
  if (!hasMask.value) return Promise.resolve(null);
  return new Promise((resolve) => {
    exportCanvas.toBlob((blob) => resolve(blob), "image/png");
  });
}

defineExpose({
  clearMask,
  hasDrawnMask,
  exportMaskBlob,
  undo,
  canUndo,
  redo,
  canRedo,
});

watch(() => props.imageUrl, async () => {
  await nextTick();
  await initializeCanvas();
});

watch(() => props.maskUrl, async () => {
  await nextTick();
  await initializeCanvas();
});
</script>

<template>
  <div class="repaint-canvas">
    <img
      ref="imageRef"
      :src="imageUrl"
      alt="局部重绘原图"
      class="repaint-image"
      @load="handleImageLoad"
    />
    <canvas
      ref="canvasRef"
      class="mask-canvas"
      @pointerdown="handlePointerDown"
      @pointermove="handlePointerMove"
      @pointerup="stopDrawing"
      @pointerleave="stopDrawing"
      @pointercancel="stopDrawing"
    />
  </div>
</template>

<style scoped lang="scss">
.repaint-canvas {
  position: relative;
  width: 100%;
  border-radius: 18px;
  overflow: hidden;
  background: #fff8ec;
  border: 1px solid #f0ddbb;
}

.repaint-image {
  width: 100%;
  display: block;
}

.mask-canvas {
  position: absolute;
  inset: 0;
  cursor: crosshair;
  touch-action: none;
}
</style>
