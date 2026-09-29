<script>
import { defineAsyncComponent, ref } from 'vue';

import NextSidebar from 'next/sidebar/Sidebar.vue';
import WootKeyShortcutModal from 'dashboard/components/widgets/modal/WootKeyShortcutModal.vue';
import AddAccountModal from 'dashboard/components/app/AddAccountModal.vue';
import UpgradePage from 'dashboard/routes/dashboard/upgrade/UpgradePage.vue';
import Logo from 'next/icon/Logo.vue';
import SidebarAccountSwitcher from 'dashboard/components-next/sidebar/SidebarAccountSwitcher.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import ButtonNext from 'dashboard/components-next/button/Button.vue';

import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { useWindowSize } from '@vueuse/core';

import wootConstants from 'dashboard/constants/globals';
import { isUpgradePageBypassRoute } from 'dashboard/helper/routeHelpers';

const CommandBar = defineAsyncComponent(
  () => import('./commands/commandbar.vue')
);

import MobileSidebarLauncher from 'dashboard/components-next/sidebar/MobileSidebarLauncher.vue';

export default {
  components: {
    NextSidebar,
    CommandBar,
    WootKeyShortcutModal,
    AddAccountModal,
    UpgradePage,
    MobileSidebarLauncher,
    Logo,
    SidebarAccountSwitcher,
    ComposeConversation,
    ButtonNext,
  },
  setup() {
    const upgradePageRef = ref(null);
    const { uiSettings, updateUISettings } = useUISettings();
    const { accountId } = useAccount();
    const { width: windowWidth } = useWindowSize();
    const searchShortcut = useKbd([`$mod`, 'k']);

    return {
      uiSettings,
      updateUISettings,
      accountId,
      upgradePageRef,
      windowWidth,
      searchShortcut,
    };
  },
  data() {
    return {
      showAccountModal: false,
      showCreateAccountModal: false,
      showShortcutModal: false,
      isMobileSidebarOpen: false,
    };
  },
  computed: {
    isSmallScreen() {
      return this.windowWidth < wootConstants.SMALL_SCREEN_BREAKPOINT;
    },
    showUpgradePage() {
      return this.upgradePageRef?.shouldShowUpgradePage;
    },
    isAccountPaywalled() {
      return this.upgradePageRef?.isAccountPaywalled;
    },
    bypassUpgradePage() {
      return isUpgradePageBypassRoute(this.$route.name);
    },
    previouslyUsedDisplayType() {
      const {
        previously_used_conversation_display_type: conversationDisplayType,
      } = this.uiSettings;
      return conversationDisplayType;
    },
  },
  watch: {
    isSmallScreen: {
      handler() {
        const { LAYOUT_TYPES } = wootConstants;
        if (window.innerWidth <= wootConstants.SMALL_SCREEN_BREAKPOINT) {
          this.updateUISettings({
            conversation_display_type: LAYOUT_TYPES.EXPANDED,
          });
        } else {
          this.updateUISettings({
            conversation_display_type: this.previouslyUsedDisplayType,
          });
        }
      },
      immediate: true,
    },
  },
  methods: {
    toggleMobileSidebar() {
      this.isMobileSidebarOpen = !this.isMobileSidebarOpen;
    },
    closeMobileSidebar() {
      this.isMobileSidebarOpen = false;
    },
    openCreateAccountModal() {
      this.showAccountModal = false;
      this.showCreateAccountModal = true;
    },
    closeCreateAccountModal() {
      this.showCreateAccountModal = false;
    },
    toggleAccountModal() {
      this.showAccountModal = !this.showAccountModal;
    },
    toggleKeyShortcutModal() {
      this.showShortcutModal = true;
    },
    closeKeyShortcutModal() {
      this.showShortcutModal = false;
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-screen w-screen overflow-hidden text-n-slate-12">
    <!-- TOP BAR HEADER (Memanjang penuh 1 baris horizontal) -->
    <header
      class="flex items-center justify-between h-12 px-3 border-b border-n-weak bg-n-background flex-shrink-0 z-40"
    >
      <!-- Sisi Kiri: Logo + Divider + Account Switcher -->
      <div class="flex items-center gap-2 min-w-0">
        <div class="grid flex-shrink-0 place-content-center size-6">
          <Logo class="size-4" />
        </div>
        <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
        <SidebarAccountSwitcher
          @show-create-account-modal="openCreateAccountModal"
        />
      </div>

      <!-- Sisi Kanan: Search bar + Compose Conversation -->
      <div class="flex items-center gap-2">
        <RouterLink
          :to="{ name: 'search', params: { accountId } }"
          class="flex gap-2 items-center px-2 py-1 w-44 sm:w-64 h-7 rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-all duration-100 ease-out hover:bg-n-alpha-2"
          :title="$t('COMBOBOX.SEARCH_PLACEHOLDER')"
        >
          <span class="flex-shrink-0 i-lucide-search size-4 text-n-slate-10" />
          <span class="flex-grow text-start text-xs text-n-slate-10 truncate">
            {{ $t('COMBOBOX.SEARCH_PLACEHOLDER') }}
          </span>
          <span
            class="hidden sm:inline-block tracking-wide pointer-events-none select-none text-xs text-n-slate-10"
          >
            {{ searchShortcut }}
          </span>
        </RouterLink>
        <ComposeConversation align="end">
          <template #trigger="{ isOpen }">
            <ButtonNext
              icon="i-lucide-pen-line"
              color="slate"
              size="sm"
              class="dark:hover:!bg-n-slate-9/30 !h-7 !outline-n-weak !text-n-slate-11"
              :class="[{ '!bg-n-alpha-2 dark:!bg-n-slate-9/30': isOpen }]"
            />
          </template>
        </ComposeConversation>
      </div>
    </header>

    <!-- BODY CONTAINER (Sidebar + Main Content) -->
    <div class="flex flex-1 min-h-0 overflow-hidden">
      <NextSidebar
        :is-mobile-sidebar-open="isMobileSidebarOpen"
        @toggle-account-modal="toggleAccountModal"
        @open-key-shortcut-modal="toggleKeyShortcutModal"
        @close-key-shortcut-modal="closeKeyShortcutModal"
        @close-mobile-sidebar="closeMobileSidebar"
      />

      <main
        class="flex flex-1 h-full w-full min-h-0 px-0 overflow-hidden bg-n-surface-1"
      >
        <UpgradePage
          v-show="showUpgradePage"
          ref="upgradePageRef"
          :bypass-upgrade-page="bypassUpgradePage"
        >
          <MobileSidebarLauncher
            :is-mobile-sidebar-open="isMobileSidebarOpen"
            @toggle="toggleMobileSidebar"
          />
        </UpgradePage>
        <template v-if="!showUpgradePage">
          <router-view />
          <MobileSidebarLauncher
            :is-mobile-sidebar-open="isMobileSidebarOpen"
            @toggle="toggleMobileSidebar"
          />
        </template>
        <CommandBar :is-paywalled="isAccountPaywalled" />
        <AddAccountModal
          :show="showCreateAccountModal"
          @close-account-create-modal="closeCreateAccountModal"
        />
        <WootKeyShortcutModal
          v-model:show="showShortcutModal"
          @close="closeKeyShortcutModal"
          @clickaway="closeKeyShortcutModal"
        />
      </main>
    </div>
  </div>
</template>
