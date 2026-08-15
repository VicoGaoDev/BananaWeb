export const CHAT_DRAFT_KEY = "generateDraftFromChat";
export const APPLY_CHAT_GENERATE_DRAFT_EVENT = "banana:apply-chat-generate-draft";
export const CLOSE_AI_ASSISTANT_DOCK_EVENT = "banana:close-ai-assistant-dock";

export function saveChatGenerateDraft(prompt: string) {
  localStorage.setItem(
    CHAT_DRAFT_KEY,
    JSON.stringify({
      mode: "imageEdit",
      prompt,
    }),
  );
}

export function applyChatGenerateDraftInPlace() {
  window.dispatchEvent(new CustomEvent(APPLY_CHAT_GENERATE_DRAFT_EVENT));
}

export function requestCloseAiAssistantDock() {
  window.dispatchEvent(new CustomEvent(CLOSE_AI_ASSISTANT_DOCK_EVENT));
}
