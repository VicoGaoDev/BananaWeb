import { nextTick, ref } from "vue";
import {
  IMAGE_FILE_ACCEPT_DEFAULT,
  IMAGE_FILE_ACCEPT_FILES,
  IMAGE_FILE_ACCEPT_GALLERY,
  isAndroidDevice,
} from "@/lib/imageFilePicker";

type PickerCallbacks = {
  onOpen?: () => void;
  onCancel?: () => void;
};

export function useImageSourcePicker() {
  const sheetOpen = ref(false);
  const accept = ref(IMAGE_FILE_ACCEPT_DEFAULT);
  let pendingInput: HTMLInputElement | null = null;
  let pendingCallbacks: PickerCallbacks | null = null;

  function requestPick(input: HTMLInputElement | null, callbacks?: PickerCallbacks) {
    if (!input) return;

    if (!isAndroidDevice()) {
      accept.value = IMAGE_FILE_ACCEPT_DEFAULT;
      callbacks?.onOpen?.();
      input.click();
      return;
    }

    pendingInput = input;
    pendingCallbacks = callbacks || null;
    sheetOpen.value = true;
  }

  async function finishPick(nextAccept: string) {
    const input = pendingInput;
    const callbacks = pendingCallbacks;
    pendingInput = null;
    pendingCallbacks = null;
    sheetOpen.value = false;
    if (!input) return;

    accept.value = nextAccept;
    callbacks?.onOpen?.();
    await nextTick();
    input.click();
  }

  function pickFromGallery() {
    void finishPick(IMAGE_FILE_ACCEPT_GALLERY);
  }

  function pickFromFiles() {
    void finishPick(IMAGE_FILE_ACCEPT_FILES);
  }

  function cancelSheet() {
    const callbacks = pendingCallbacks;
    pendingInput = null;
    pendingCallbacks = null;
    sheetOpen.value = false;
    callbacks?.onCancel?.();
  }

  return {
    accept,
    sheetOpen,
    requestPick,
    pickFromGallery,
    pickFromFiles,
    cancelSheet,
  };
}
