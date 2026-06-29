import client from "./client";
import type {
  CanvasDetail,
  CanvasNode,
  CanvasTaskCreateResponse,
  CanvasTaskPayload,
  UserCanvasListResponse,
  UserCanvasSummary,
} from "@/types";

export function listCanvases(): Promise<UserCanvasListResponse> {
  return client.get("/canvases");
}

export function createCanvas(name: string = "新画布"): Promise<UserCanvasSummary> {
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
