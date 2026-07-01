import client from "./client";
import type {
  CanvasDetail,
  CanvasEdge,
  CanvasNode,
  CanvasTaskCreateResponse,
  CanvasTaskPayload,
  UserCanvasListResponse,
  UserCanvasSummary,
} from "@/types";

export function listCanvases(): Promise<UserCanvasListResponse> {
  return client.get("/canvases");
}

export function getDefaultCanvasName(date = new Date()): string {
  const year = String(date.getFullYear()).slice(-2);
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `新画板-${year}${month}${day}`;
}

export function createCanvas(name: string = getDefaultCanvasName()): Promise<UserCanvasSummary> {
  return client.post("/canvases", { name });
}

export function getCanvas(projectId: string): Promise<CanvasDetail> {
  return client.get(`/canvases/${projectId}`);
}

export function updateCanvas(projectId: string, data: { name?: string; viewport_x?: number; viewport_y?: number; zoom?: number }): Promise<UserCanvasSummary> {
  return client.patch(`/canvases/${projectId}`, data);
}

export function deleteCanvas(projectId: string): Promise<void> {
  return client.delete(`/canvases/${projectId}`);
}

export function updateCanvasViewport(projectId: string, data: { viewport_x: number; viewport_y: number; zoom: number }): Promise<UserCanvasSummary> {
  return client.patch(`/canvases/${projectId}/viewport`, data);
}

export function updateCanvasNode(projectId: string, nodeId: number, data: Partial<Pick<CanvasNode, "x" | "y" | "width" | "height" | "z_index" | "content">>): Promise<CanvasNode> {
  return client.patch(`/canvases/${projectId}/nodes/${nodeId}`, data);
}

export function updateCanvasNodesBatch(projectId: string, nodes: Array<Partial<Pick<CanvasNode, "x" | "y" | "width" | "height" | "z_index" | "content">> & { id: number }>): Promise<{ nodes: CanvasNode[] }> {
  return client.patch(`/canvases/${projectId}/nodes/batch`, { nodes });
}

export function deleteCanvasNode(projectId: string, nodeId: number): Promise<void> {
  return client.delete(`/canvases/${projectId}/nodes/${nodeId}`);
}

export function updateCanvasEdge(projectId: string, edgeId: number, data: { is_collapsed?: boolean }): Promise<CanvasEdge> {
  return client.patch(`/canvases/${projectId}/edges/${edgeId}`, data);
}

export function createCanvasNode(projectId: string, data: {
  node_type: "text" | "image";
  content?: string;
  image_url?: string;
  x: number;
  y: number;
  width?: number;
  height?: number;
}): Promise<CanvasNode> {
  return client.post(`/canvases/${projectId}/nodes`, data);
}

export function createCanvasTask(projectId: string, data: CanvasTaskPayload): Promise<CanvasTaskCreateResponse> {
  return client.post(`/canvases/${projectId}/tasks`, {
    ...data,
    source: data.source || "web",
  });
}
