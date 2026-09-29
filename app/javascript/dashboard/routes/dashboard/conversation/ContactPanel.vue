<script setup>
import { computed, watch, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  useMapGetter,
  useFunctionGetter,
  useStore,
} from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import ContactConversations from './ContactConversations.vue';
import ConversationAction from './ConversationAction.vue';
import ConversationParticipant from './ConversationParticipant.vue';
import ContactInfo from './contact/ContactInfo.vue';
import ContactNotes from './contact/ContactNotes.vue';
import ConversationInfo from './ConversationInfo.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';
import SharedFiles from './SharedFiles.vue';
import MacrosList from './Macros/List.vue';
import ShopifyOrdersList from 'dashboard/components/widgets/conversation/ShopifyOrdersList.vue';
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';
import LinearIssuesList from 'dashboard/components/widgets/conversation/linear/IssuesList.vue';
import LinearSetupCTA from 'dashboard/components/widgets/conversation/linear/LinearSetupCTA.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: Number,
    default: undefined,
  },
});

const {
  updateUISettings,
  isContactSidebarItemOpen,
  toggleSidebarUIState,
  isOnExpandedLayout,
} = useUISettings();

const { t } = useI18n();
const activeTabKey = ref('ticket');

const tabs = computed(() => [
  {
    key: 'ticket',
    icon: 'i-lucide-ticket',
    label: t('CONTACT_PANEL.SIDEBAR_TABS.TICKET'),
  },
  {
    key: 'customer',
    icon: 'i-lucide-user',
    label: t('CONTACT_PANEL.SIDEBAR_TABS.CUSTOMER'),
  },
  {
    key: 'apps',
    icon: 'i-lucide-layout-grid',
    label: t('CONTACT_PANEL.SIDEBAR_TABS.APPS'),
  },
]);

const shopifyIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'shopify'
);

const isShopifyFeatureEnabled = computed(
  () => shopifyIntegration.value.enabled
);

const { isCloudFeatureEnabled } = useAccount();

const isLinearFeatureEnabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.LINEAR)
);

const linearIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'linear'
);

const isLinearClientIdConfigured = computed(() => {
  return !!linearIntegration.value?.id;
});

const isLinearConnected = computed(
  () => linearIntegration.value?.enabled || false
);

const store = useStore();
const currentChat = useMapGetter('getSelectedChat');
const conversationId = computed(() => props.conversationId);
const conversationMetadataGetter = useMapGetter(
  'conversationMetadata/getConversationMetadata'
);
const currentConversationMetaData = computed(() =>
  conversationMetadataGetter.value(conversationId.value)
);
const conversationAdditionalAttributes = computed(
  () => currentConversationMetaData.value.additional_attributes || {}
);

const channelType = computed(() => currentChat.value.meta?.channel);

const contactGetter = useMapGetter('contacts/getContact');
const contactId = computed(() => currentChat.value.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value));
const contactAdditionalAttributes = computed(
  () => contact.value.additional_attributes || {}
);

const appliedContactFilter = useMapGetter('getAppliedContactFilter');

const isListScopedToContact = computed(
  () =>
    !isOnExpandedLayout.value &&
    appliedContactFilter.value?.id === contactId.value
);

const getContactDetails = () => {
  if (contactId.value) {
    store.dispatch('contacts/show', { id: contactId.value });
  }
};

watch(contactId, (newContactId, prevContactId) => {
  if (newContactId && newContactId !== prevContactId) {
    getContactDetails();
  }
});

const closeContactPanel = () => {
  updateUISettings({
    is_contact_sidebar_open: false,
    is_copilot_panel_open: false,
  });
};

onMounted(() => {
  getContactDetails();
  store.dispatch('attributes/get', 0);
  // Load integrations to ensure linear integration state is available
  store.dispatch('integrations/get', 'linear');
});
</script>

<template>
  <div class="w-full">
    <SidebarActionsHeader
      :title="$t('CONVERSATION.SIDEBAR.CONTACT')"
      @close="closeContactPanel"
    />
    <ContactInfo :contact="contact" :channel-type="channelType" />

    <!-- SEGMENTED TABS NAVIGATOR -->
    <div class="px-3 pt-1 pb-3 sticky top-0 bg-n-surface-2 z-10">
      <div
        role="tablist"
        :aria-label="$t('CONTACT_PANEL.TABS_LABEL')"
        class="grid grid-cols-3 p-1 rounded-xl bg-n-alpha-2 border border-n-weak/60 gap-1 text-xs font-medium"
      >
        <button
          v-for="tab in tabs"
          :key="tab.key"
          type="button"
          role="tab"
          :aria-selected="activeTabKey === tab.key"
          class="flex items-center justify-center gap-1.5 py-1.5 px-2 rounded-lg transition-all duration-150 cursor-pointer select-none text-xs"
          :class="
            activeTabKey === tab.key
              ? 'bg-n-surface-1 text-n-slate-12 shadow-sm font-semibold'
              : 'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1'
          "
          @click="activeTabKey = tab.key"
        >
          <span :class="tab.icon" class="size-3.5" />
          <span class="truncate">{{ tab.label }}</span>
        </button>
      </div>
    </div>

    <!-- TAB 1: TICKET -->
    <div
      v-show="activeTabKey === 'ticket'"
      class="px-2 pb-8 flex flex-col gap-3"
    >
      <div class="conversation--actions">
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_ACTIONS')"
          :is-open="isContactSidebarItemOpen('is_conv_actions_open')"
          @toggle="value => toggleSidebarUIState('is_conv_actions_open', value)"
        >
          <ConversationAction
            :conversation-id="conversationId"
            :inbox-id="inboxId"
          />
        </AccordionItem>
      </div>
      <div class="conversation--actions">
        <AccordionItem
          :title="$t('CONVERSATION_PARTICIPANTS.SIDEBAR_TITLE')"
          :is-open="isContactSidebarItemOpen('is_conv_participants_open')"
          @toggle="
            value => toggleSidebarUIState('is_conv_participants_open', value)
          "
        >
          <ConversationParticipant
            :conversation-id="conversationId"
            :inbox-id="inboxId"
          />
        </AccordionItem>
      </div>
      <woot-feature-toggle feature-key="macros">
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.MACROS')"
          :is-open="isContactSidebarItemOpen('is_macro_open')"
          compact
          @toggle="value => toggleSidebarUIState('is_macro_open', value)"
        >
          <MacrosList :conversation-id="conversationId" />
        </AccordionItem>
      </woot-feature-toggle>
      <div>
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_INFO')"
          :is-open="isContactSidebarItemOpen('is_conv_details_open')"
          compact
          @toggle="value => toggleSidebarUIState('is_conv_details_open', value)"
        >
          <ConversationInfo
            :conversation-attributes="conversationAdditionalAttributes"
            :contact-attributes="contactAdditionalAttributes"
          />
        </AccordionItem>
      </div>
    </div>

    <!-- TAB 2: CUSTOMER -->
    <div
      v-show="activeTabKey === 'customer'"
      class="px-2 pb-8 flex flex-col gap-3"
    >
      <div>
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_NOTES')"
          :is-open="isContactSidebarItemOpen('is_contact_notes_open')"
          compact
          @toggle="
            value => toggleSidebarUIState('is_contact_notes_open', value)
          "
        >
          <ContactNotes :contact-id="contactId" />
        </AccordionItem>
      </div>
      <div>
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_ATTRIBUTES')"
          :is-open="isContactSidebarItemOpen('is_contact_attributes_open')"
          compact
          @toggle="
            value => toggleSidebarUIState('is_contact_attributes_open', value)
          "
        >
          <CustomAttributes
            attribute-type="contact_attribute"
            attribute-from="conversation_contact_panel"
            :contact-id="contact.id"
            :empty-state-message="
              $t('CONVERSATION_CUSTOM_ATTRIBUTES.NO_RECORDS_FOUND')
            "
          />
        </AccordionItem>
      </div>
      <div v-if="!isListScopedToContact && contact.id">
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.PREVIOUS_CONVERSATION')"
          :is-open="isContactSidebarItemOpen('is_previous_conv_open')"
          compact
          @toggle="
            value => toggleSidebarUIState('is_previous_conv_open', value)
          "
        >
          <ContactConversations
            :contact-id="contact.id"
            :conversation-id="conversationId"
          />
        </AccordionItem>
      </div>
    </div>

    <!-- TAB 3: APPS & MEDIA -->
    <div v-show="activeTabKey === 'apps'" class="px-2 pb-8 flex flex-col gap-3">
      <div>
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.SHARED_FILES')"
          :is-open="isContactSidebarItemOpen('is_shared_files_open')"
          compact
          @toggle="value => toggleSidebarUIState('is_shared_files_open', value)"
        >
          <SharedFiles />
        </AccordionItem>
      </div>
      <div v-if="isShopifyFeatureEnabled">
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.SHOPIFY_ORDERS')"
          :is-open="isContactSidebarItemOpen('is_shopify_orders_open')"
          compact
          @toggle="
            value => toggleSidebarUIState('is_shopify_orders_open', value)
          "
        >
          <ShopifyOrdersList :contact-id="contactId" />
        </AccordionItem>
      </div>
      <div v-if="isLinearFeatureEnabled && isLinearClientIdConfigured">
        <AccordionItem
          :title="$t('CONVERSATION_SIDEBAR.ACCORDION.LINEAR_ISSUES')"
          :is-open="isContactSidebarItemOpen('is_linear_issues_open')"
          compact
          @toggle="
            value => toggleSidebarUIState('is_linear_issues_open', value)
          "
        >
          <LinearSetupCTA v-if="!isLinearConnected" />
          <LinearIssuesList v-else :conversation-id="conversationId" />
        </AccordionItem>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
:deep(.contact--profile) {
  @apply pb-3 border-b border-solid border-n-weak;
}
</style>
