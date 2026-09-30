<script setup>
import { computed } from 'vue';
import ContactPanel from 'dashboard/routes/dashboard/conversation/ContactPanel.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { useContactSidebarResize } from 'dashboard/composables/conversation/useContactSidebarResize';

defineProps({
  currentChat: {
    required: true,
    type: Object,
  },
});

const DESKTOP_EXPANDED_BREAKPOINT = 768;

const { uiSettings, updateUISettings } = useUISettings();
const { width: windowWidth } = useWindowSize();

const activeTab = computed(() => {
  const { is_contact_sidebar_open: isContactSidebarOpen } = uiSettings.value;

  if (isContactSidebarOpen) {
    return 0;
  }
  return null;
});

const isSmallScreen = computed(
  () => windowWidth.value < DESKTOP_EXPANDED_BREAKPOINT
);

const {
  contactSidebarWidth,
  isResizing,
  onResizeStart,
  onResizeHandleDoubleClick,
} = useContactSidebarResize();

const sidebarStyle = computed(() => {
  if (isSmallScreen.value) return undefined;
  return {
    width: `${contactSidebarWidth.value}px`,
    minWidth: `${contactSidebarWidth.value}px`,
  };
});

const closeContactPanel = () => {
  if (isSmallScreen.value && uiSettings.value?.is_contact_sidebar_open) {
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
    });
  }
};
</script>

<template>
  <div
    v-on-click-outside="[
      () => closeContactPanel(),
      {
        ignore: [
          'dialog.ProseMirror-prompt-backdrop',
          '[data-popover-content]',
          '[data-popover-backdrop]',
          '[data-resize-handle]',
        ],
      },
    ]"
    class="bg-n-surface-2 h-full flex-col fixed top-0 z-40 w-full max-w-sm md:max-w-none transition-transform duration-300 ease-in-out ltr:right-0 rtl:left-0 md:relative md:top-auto md:right-auto md:left-auto ltr:border-l rtl:border-r border-n-weak shadow-lg md:shadow-none flex-shrink-0"
    :class="[
      activeTab === 0 ? 'flex' : 'hidden',
      { 'transition-[width] duration-150 ease-out': !isResizing },
    ]"
    :style="sidebarStyle"
  >
    <!-- Resize Handle (desktop / laptop md+) -->
    <div
      data-resize-handle="true"
      class="hidden md:block absolute top-0 h-full w-4 cursor-col-resize z-50 ltr:-left-2 rtl:-right-2 group select-none"
      @mousedown="onResizeStart"
      @touchstart="onResizeStart"
      @dblclick="onResizeHandleDoubleClick"
    >
      <div
        class="absolute top-0 h-full w-1 ltr:left-1.5 rtl:right-1.5 bg-transparent group-hover:bg-n-brand transition-colors pointer-events-none"
        :class="{ 'bg-n-brand': isResizing }"
      />
    </div>

    <div class="flex flex-1 overflow-auto">
      <ContactPanel
        v-show="activeTab === 0"
        :conversation-id="currentChat.id"
        :inbox-id="currentChat.inbox_id"
      />
    </div>
  </div>
</template>
