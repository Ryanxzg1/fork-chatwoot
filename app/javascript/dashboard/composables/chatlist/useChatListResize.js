import { ref, watch } from 'vue';
import { useWindowSize, useEventListener } from '@vueuse/core';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store.js';

// Menjamin ruang horizontal yang cukup agar elemen internal (misal ConversationStatusFilterPills & ChatListHeader)
// tidak terpotong di berbagai bahasa pada layout terkondensasi.
export const MIN_CHAT_LIST_WIDTH = 410;
export const DEFAULT_CHAT_LIST_WIDTH = 410;
export const DEFAULT_CHAT_LIST_WIDTH_2XL = 450;
export const MAX_WIDTH_RATIO = 0.5;

export function useChatListResize() {
  const { uiSettings, updateUISettings } = useUISettings();
  const isRTL = useMapGetter('accounts/isRTL');
  const { width: windowWidth } = useWindowSize();

  const getDefaultWidth = () => {
    if (typeof window === 'undefined') return DEFAULT_CHAT_LIST_WIDTH;
    return window.innerWidth >= 1536
      ? DEFAULT_CHAT_LIST_WIDTH_2XL
      : DEFAULT_CHAT_LIST_WIDTH;
  };

  const getMaxWidth = () => {
    if (typeof window === 'undefined') return 600;
    return Math.max(
      MIN_CHAT_LIST_WIDTH,
      Math.floor(window.innerWidth * MAX_WIDTH_RATIO)
    );
  };

  const clampWidth = width => {
    const max = getMaxWidth();
    return Math.max(MIN_CHAT_LIST_WIDTH, Math.min(max, width));
  };

  const initialSavedWidth = Number(uiSettings.value?.conversation_list_width);
  const chatListWidth = ref(
    Number.isFinite(initialSavedWidth) && initialSavedWidth > 0
      ? clampWidth(initialSavedWidth)
      : getDefaultWidth()
  );

  const isResizing = ref(false);
  const startX = ref(0);
  const startWidth = ref(0);

  // Clamp current width when screen shrinks below the current width limit
  watch(windowWidth, () => {
    const max = getMaxWidth();
    if (chatListWidth.value > max) {
      chatListWidth.value = max;
    }
  });

  const getClientX = event =>
    event.touches ? event.touches[0].clientX : event.clientX;

  const onResizeStart = event => {
    isResizing.value = true;
    startX.value = getClientX(event);
    startWidth.value = chatListWidth.value;

    if (typeof document !== 'undefined') {
      Object.assign(document.body.style, {
        cursor: 'col-resize',
        userSelect: 'none',
      });
    }

    event.preventDefault();
  };

  const onResizeMove = event => {
    if (!isResizing.value) return;

    const currentX = getClientX(event);
    const delta = isRTL.value
      ? startX.value - currentX
      : currentX - startX.value;

    chatListWidth.value = clampWidth(startWidth.value + delta);
  };

  const onResizeEnd = () => {
    if (!isResizing.value) return;

    isResizing.value = false;
    if (typeof document !== 'undefined') {
      Object.assign(document.body.style, { cursor: '', userSelect: '' });
    }

    updateUISettings({ conversation_list_width: chatListWidth.value });
  };

  const onResizeHandleDoubleClick = () => {
    const defaultWidth = getDefaultWidth();
    chatListWidth.value = defaultWidth;
    updateUISettings({ conversation_list_width: defaultWidth });
  };

  useEventListener(document, 'mousemove', onResizeMove);
  useEventListener(document, 'mouseup', onResizeEnd);
  useEventListener(document, 'touchmove', onResizeMove, { passive: false });
  useEventListener(document, 'touchend', onResizeEnd);

  return {
    chatListWidth,
    isResizing,
    onResizeStart,
    onResizeHandleDoubleClick,
    resetToDefaultWidth: onResizeHandleDoubleClick,
    MIN_CHAT_LIST_WIDTH,
    getDefaultWidth,
    getMaxWidth,
  };
}
