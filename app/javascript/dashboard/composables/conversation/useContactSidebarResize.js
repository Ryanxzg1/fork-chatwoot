import { ref, watch } from 'vue';
import { useWindowSize, useEventListener } from '@vueuse/core';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store.js';

export const MIN_CONTACT_SIDEBAR_WIDTH = 300;
export const DEFAULT_CONTACT_SIDEBAR_WIDTH = 320;
export const DEFAULT_CONTACT_SIDEBAR_WIDTH_2XL = 360;
export const MAX_CONTACT_SIDEBAR_WIDTH = 700;
export const MAX_WIDTH_RATIO = 0.45;

export function useContactSidebarResize() {
  const { uiSettings, updateUISettings } = useUISettings();
  const isRTL = useMapGetter('accounts/isRTL');
  const { width: windowWidth } = useWindowSize();

  const getDefaultWidth = () => {
    if (typeof window === 'undefined') return DEFAULT_CONTACT_SIDEBAR_WIDTH;
    return window.innerWidth >= 1536
      ? DEFAULT_CONTACT_SIDEBAR_WIDTH_2XL
      : DEFAULT_CONTACT_SIDEBAR_WIDTH;
  };

  const getMaxWidth = () => {
    if (typeof window === 'undefined') return MAX_CONTACT_SIDEBAR_WIDTH;
    const computedMax = Math.floor(window.innerWidth * MAX_WIDTH_RATIO);
    return Math.max(
      MIN_CONTACT_SIDEBAR_WIDTH,
      Math.min(MAX_CONTACT_SIDEBAR_WIDTH, computedMax)
    );
  };

  const clampWidth = width => {
    const max = getMaxWidth();
    return Math.max(MIN_CONTACT_SIDEBAR_WIDTH, Math.min(max, width));
  };

  const initialSavedWidth = Number(uiSettings.value?.contact_sidebar_width);
  const contactSidebarWidth = ref(
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
    if (contactSidebarWidth.value > max) {
      contactSidebarWidth.value = max;
    }
  });

  const getClientX = event =>
    event.touches ? event.touches[0].clientX : event.clientX;

  const onResizeStart = event => {
    isResizing.value = true;
    startX.value = getClientX(event);
    startWidth.value = contactSidebarWidth.value;

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
    // In LTR: Sidebar is on the right, dragging left increases width
    // In RTL: Sidebar is on the left, dragging right increases width
    const delta = isRTL.value
      ? currentX - startX.value
      : startX.value - currentX;

    contactSidebarWidth.value = clampWidth(startWidth.value + delta);
  };

  const onResizeEnd = () => {
    if (!isResizing.value) return;

    isResizing.value = false;
    if (typeof document !== 'undefined') {
      Object.assign(document.body.style, { cursor: '', userSelect: '' });
    }

    updateUISettings({ contact_sidebar_width: contactSidebarWidth.value });
  };

  const onResizeHandleDoubleClick = () => {
    const defaultWidth = getDefaultWidth();
    contactSidebarWidth.value = defaultWidth;
    updateUISettings({ contact_sidebar_width: defaultWidth });
  };

  useEventListener(document, 'mousemove', onResizeMove);
  useEventListener(document, 'mouseup', onResizeEnd);
  useEventListener(document, 'touchmove', onResizeMove, { passive: false });
  useEventListener(document, 'touchend', onResizeEnd);

  return {
    contactSidebarWidth,
    isResizing,
    onResizeStart,
    onResizeHandleDoubleClick,
    resetToDefaultWidth: onResizeHandleDoubleClick,
    MIN_CONTACT_SIDEBAR_WIDTH,
    getDefaultWidth,
    getMaxWidth,
  };
}
