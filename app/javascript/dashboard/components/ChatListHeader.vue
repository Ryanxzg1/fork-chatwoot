<script setup>
import { computed, getCurrentInstance } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
  DropdownSeparator,
} from 'next/dropdown-menu/base';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';

const props = defineProps({
  pageTitle: { type: String, required: true },
  contactFilter: { type: Object, default: null },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
  activeAssigneeTab: { type: String, default: wootConstants.ASSIGNEE_TYPE.ALL },
  assigneeTabItems: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
  'assigneeTabChange',
]);

const { t } = useI18n();
const router = useRouter?.();
const route = useRoute?.();
const vm = getCurrentInstance();
const store = vm?.proxy?.$store;

const currentAccountId = computed(() => store?.getters?.getCurrentAccountId);
const allUnreadCount = computed(
  () => store?.getters?.['conversationUnreadCounts/getAllUnreadCount'] || 0
);
const mentionsUnreadCount = computed(
  () => store?.getters?.['conversationUnreadCounts/getMentionsUnreadCount'] || 0
);
const participatingUnreadCount = computed(
  () =>
    store?.getters?.['conversationUnreadCounts/getParticipatingUnreadCount'] ||
    0
);
const unattendedUnreadCount = computed(
  () =>
    store?.getters?.['conversationUnreadCounts/getUnattendedUnreadCount'] || 0
);

const { uiSettings, updateUISettings } = useUISettings();

provideDropdownTeleport();

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));

// While filters narrow the list, the header names it and the back button exits.
const showFilterScope = computed(
  () => props.hasAppliedFilters && !props.hasActiveFolders
);

// The contact scope is set from the contact panel; it is exited, not edited.
const isContactScoped = computed(
  () => showFilterScope.value && !!props.contactFilter
);

const title = computed(
  () => (isContactScoped.value && props.contactFilter.name) || props.pageTitle
);

const activeAssigneeName = computed(() => {
  const activeItem = props.assigneeTabItems?.find(
    item => item.key === props.activeAssigneeTab
  );
  return activeItem?.name || t('CHAT_LIST.ASSIGNEE_TYPE_TABS.all');
});

const headerDropdownTitle = computed(() => {
  return `${title.value}: ${activeAssigneeName.value}`;
});

const shouldShowDropdown = computed(() => {
  return (
    !hasAppliedFiltersOrActiveFolders.value &&
    !isContactScoped.value &&
    props.assigneeTabItems?.length > 0
  );
});

const getAssigneeIcon = key => {
  switch (key) {
    case 'me':
      return 'i-lucide-user';
    case 'unassigned':
      return 'i-lucide-user-x';
    case 'all':
    default:
      return 'i-lucide-users';
  }
};

const conversationViewItems = computed(() => [
  {
    key: 'all',
    name: t('SIDEBAR.ALL_CONVERSATIONS'),
    icon: 'i-lucide-inbox',
    count: allUnreadCount.value,
    routeName: 'home',
    isActive: route?.name === 'home' || route?.name === 'inbox_conversation',
  },
  {
    key: 'mentions',
    name: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
    icon: 'i-lucide-at-sign',
    count: mentionsUnreadCount.value,
    routeName: 'conversation_mentions',
    isActive:
      route?.name === 'conversation_mentions' ||
      route?.name === 'conversation_through_mentions',
  },
  {
    key: 'participating',
    name: t('SIDEBAR.PARTICIPATING_CONVERSATIONS'),
    icon: 'i-lucide-user-round-check',
    count: participatingUnreadCount.value,
    routeName: 'conversation_participating',
    isActive:
      route?.name === 'conversation_participating' ||
      route?.name === 'conversation_through_participating',
  },
  {
    key: 'unattended',
    name: t('SIDEBAR.UNATTENDED_CONVERSATIONS'),
    icon: 'i-lucide-clock-alert',
    count: unattendedUnreadCount.value,
    routeName: 'conversation_unattended',
    isActive:
      route?.name === 'conversation_unattended' ||
      route?.name === 'conversation_through_unattended',
  },
]);

const onSelectAssigneeTab = key => {
  emit('assigneeTabChange', key);
};

const onSelectView = view => {
  if (router && currentAccountId.value) {
    router.push({
      name: view.routeName,
      params: { accountId: currentAccountId.value },
    });
  }
};

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};
</script>

<template>
  <div
    class="relative z-20 flex items-center justify-between gap-2 px-3 h-[3.25rem]"
    :class="{
      'border-b border-n-strong': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <div class="flex items-center justify-center min-w-0">
      <NextButton
        v-if="showFilterScope"
        v-tooltip.right="$t('FILTER.CLEAR_BUTTON_LABEL')"
        :aria-label="$t('FILTER.CLEAR_BUTTON_LABEL')"
        icon="i-lucide-chevron-left"
        class="shrink-0 -ms-2 !h-6 !w-6 me-1"
        slate
        sm
        ghost
        @click="emit('resetFilters')"
      />
      <DropdownContainer v-if="shouldShowDropdown">
        <template #trigger="{ toggle, isOpen }">
          <button
            type="button"
            class="flex items-center gap-1.5 px-2 py-1 -ms-2 rounded-lg hover:bg-n-alpha-2 transition-colors cursor-pointer text-start min-w-0"
            :class="{ 'bg-n-alpha-2': isOpen }"
            :title="headerDropdownTitle"
            @click="toggle"
          >
            <h1 class="text-base font-medium truncate text-n-slate-12">
              {{ headerDropdownTitle }}
            </h1>
            <span
              class="i-lucide-chevron-down size-4 text-n-slate-11 shrink-0 transition-transform duration-150"
              :class="{ 'rotate-180': isOpen }"
            />
          </button>
        </template>
        <DropdownBody class="w-64 z-50">
          <DropdownSection :title="$t('CHAT_LIST.TAB_HEADING')">
            <DropdownItem
              v-for="item in assigneeTabItems"
              :key="item.key"
              :icon="getAssigneeIcon(item.key)"
              class="justify-between hover:bg-n-alpha-2 rounded-lg"
              :click="() => onSelectAssigneeTab(item.key)"
            >
              <div class="flex items-center justify-between w-full">
                <span
                  class="text-sm"
                  :class="{
                    'font-medium text-n-brand': activeAssigneeTab === item.key,
                  }"
                >
                  {{ item.name }}
                </span>
                <span
                  v-if="item.count"
                  class="inline-grid h-5 min-w-5 place-items-center rounded-full bg-n-slate-4 px-1.5 text-xxs font-medium text-n-slate-12"
                >
                  {{ item.count }}
                </span>
              </div>
            </DropdownItem>
          </DropdownSection>
          <DropdownSeparator />
          <DropdownSection :title="$t('SIDEBAR.CONVERSATIONS')">
            <DropdownItem
              v-for="view in conversationViewItems"
              :key="view.key"
              :icon="view.icon"
              class="justify-between hover:bg-n-alpha-2 rounded-lg"
              :click="() => onSelectView(view)"
            >
              <div class="flex items-center justify-between w-full">
                <span
                  class="text-sm"
                  :class="{
                    'font-medium text-n-brand': view.isActive,
                  }"
                >
                  {{ view.name }}
                </span>
                <span
                  v-if="view.count"
                  class="inline-grid h-5 min-w-5 place-items-center rounded-full bg-n-slate-4 px-1.5 text-xxs font-medium text-n-slate-12"
                >
                  {{ view.count }}
                </span>
              </div>
            </DropdownItem>
          </DropdownSection>
        </DropdownBody>
      </DropdownContainer>
      <h1
        v-else
        class="text-base font-medium truncate text-n-slate-12"
        :title="title"
      >
        {{ title }}
      </h1>
      <span
        v-if="
          allCount > 0 && hasAppliedFiltersOrActiveFolders && !isListLoading
        "
        class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
        :title="allCount"
      >
        {{ formattedAllCount }}
      </span>
    </div>
    <div class="flex items-center gap-1">
      <template v-if="hasAppliedFilters && !hasActiveFolders">
        <div class="relative">
          <NextButton
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
            icon="i-lucide-save"
            slate
            xs
            faded
            @click="emit('addFolders')"
          />
          <div
            id="saveFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
      </template>
      <template v-if="hasActiveFolders">
        <div class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
            icon="i-lucide-pen-line"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
          icon="i-lucide-trash-2"
          ruby
          xs
          faded
          @click="emit('deleteFolders')"
        />
      </template>
      <div v-else-if="!isContactScoped" class="relative">
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
          icon="i-lucide-list-filter"
          slate
          xs
          faded
          @click="emit('filtersModal')"
        />
        <div
          id="conversationFilterTeleportTarget"
          class="absolute z-50 mt-2"
          :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
        />
      </div>
      <ConversationBasicFilter
        v-if="!isContactScoped"
        :is-on-expanded-layout="isOnExpandedLayout"
        @change-filter="onBasicFilterChange"
      />
      <SwitchLayout
        :is-on-expanded-layout="isOnExpandedLayout"
        @toggle="toggleConversationLayout"
      />
    </div>
  </div>
</template>
