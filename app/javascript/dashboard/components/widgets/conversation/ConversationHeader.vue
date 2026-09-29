<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import SidepanelSwitch from 'dashboard/components-next/Conversation/SidepanelSwitch.vue';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { useInbox } from 'dashboard/composables/useInbox';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const { uiSettings, updateUISettings } = useUISettings();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();

const isContactSidebarOpen = computed(
  () => uiSettings.value.is_contact_sidebar_open
);

const handleContactProfileToggle = () => {
  updateUISettings({
    is_contact_sidebar_open: !isContactSidebarOpen.value,
    is_copilot_panel_open: false,
  });
};

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_participating: 'participating',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !currentContact.value?.blocked
);

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(props.chat.id));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex flex-col sm:flex-row gap-2.5 sm:gap-4 items-start sm:items-center justify-between flex-1 w-full min-w-0 px-3.5 py-2 sm:py-0 min-h-[3.25rem] sm:h-14 bg-n-surface-1"
  >
    <div
      class="flex items-center justify-start w-full sm:w-auto max-w-full min-w-0 sm:flex-1"
    >
      <BackButton
        v-if="showBackButton"
        :back-url="backButtonUrl"
        class="me-2"
      />
      <div class="flex items-center min-w-0">
        <button
          type="button"
          class="flex-shrink-0 rounded-full focus-visible:outline-1 focus-visible:outline-n-brand"
          :title="$t('CONVERSATION.SIDEBAR.CONTACT')"
          @click="handleContactProfileToggle"
        >
          <Avatar
            :name="currentContact.name"
            :src="currentContact.thumbnail"
            :size="32"
            :status="currentContact.availability_status"
            hide-offline-status
          />
        </button>
        <div
          class="flex flex-col justify-center items-start min-w-0 ms-2.5 overflow-hidden"
        >
          <button
            type="button"
            class="flex flex-row items-center max-w-full gap-1.5 p-0 m-0 text-start group cursor-pointer focus-visible:outline-1 focus-visible:outline-n-brand rounded"
            :title="$t('CONVERSATION.SIDEBAR.CONTACT')"
            @click="handleContactProfileToggle"
          >
            <span
              class="text-sm font-semibold truncate leading-tight text-n-slate-12 group-hover:text-n-brand transition-colors"
            >
              {{ currentContact.name }}
            </span>
            <fluent-icon
              v-if="!isHMACVerified"
              v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
              size="14"
              class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
              icon="warning"
            />
          </button>

          <div
            class="flex items-center gap-1.5 overflow-hidden text-xs conversation--header--actions text-n-slate-11 text-ellipsis whitespace-nowrap mt-0.5"
          >
            <button
              type="button"
              class="truncate text-label-small text-n-slate-11 hover:text-n-slate-12 !p-0 cursor-pointer hover:underline"
              @click.stop="copyConversationId"
            >
              {{ `#${chat.id}` }}
            </button>
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            <span v-if="hasMultipleInboxes" class="text-n-slate-8">•</span>
            <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
          </div>
        </div>
      </div>
    </div>
    <div
      class="flex flex-row items-center justify-end flex-shrink-0 gap-1.5 sm:gap-2 w-full sm:w-auto header-actions-wrap"
    >
      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="hidden md:flex"
      />
      <ConversationCallButton :inbox="inbox" :chat="currentChat" />
      <MoreActions :conversation-id="currentChat.id" />
      <div class="w-px h-5 bg-n-strong mx-0.5 opacity-60" />
      <SidepanelSwitch />
    </div>
  </div>
</template>
