import client from "./client";
import type {
  ChatMessageListResponse,
  ChatSendMessageResponse,
  ChatSession,
  ChatSessionListResponse,
} from "@/types";

export function listChatSessions(params?: {
  page?: number;
  page_size?: number;
}): Promise<ChatSessionListResponse> {
  return client.get("/chat/sessions", { params });
}

export function createChatSession(payload: {
  title?: string;
  model: string;
}): Promise<ChatSession> {
  return client.post("/chat/sessions", payload);
}

export function getChatSession(sessionId: string): Promise<ChatSession> {
  return client.get(`/chat/sessions/${sessionId}`);
}

export function updateChatSession(
  sessionId: string,
  payload: { title?: string; model?: string },
): Promise<ChatSession> {
  return client.patch(`/chat/sessions/${sessionId}`, payload);
}

export function deleteChatSession(sessionId: string): Promise<void> {
  return client.delete(`/chat/sessions/${sessionId}`);
}

export function listChatMessages(
  sessionId: string,
  params?: { before_id?: number; page_size?: number },
): Promise<ChatMessageListResponse> {
  return client.get(`/chat/sessions/${sessionId}/messages`, { params });
}

/** 对话发送会同步等待上游模型，需覆盖后端 AI_TIMEOUT（默认 600s） */
const CHAT_SEND_TIMEOUT_MS = 630_000;

export function sendChatMessage(
  sessionId: string,
  payload: {
    content: string;
    model?: string;
    client_message_id: string;
  },
  signal?: AbortSignal,
): Promise<ChatSendMessageResponse> {
  return client.post(`/chat/sessions/${sessionId}/messages`, payload, {
    timeout: CHAT_SEND_TIMEOUT_MS,
    signal,
  });
}
