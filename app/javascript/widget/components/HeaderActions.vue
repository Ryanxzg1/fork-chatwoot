<script>
import { mapGetters } from 'vuex';
import { useRouter } from 'vue-router';
import { IFrameHelper, RNHelper } from 'widget/helpers/utils';
import { popoutChatWindow } from '../helpers/popoutHelper';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import Spinner from 'shared/components/Spinner.vue';
import configMixin from 'widget/mixins/configMixin';
import { CONVERSATION_STATUS } from 'shared/constants/messages';

export default {
  name: 'HeaderActions',
  components: { FluentIcon, Spinner },
  mixins: [configMixin],
  props: {
    showPopoutButton: {
      type: Boolean,
      default: false,
    },
    showEndConversationButton: {
      type: Boolean,
      default: true,
    },
  },
  setup() {
    const router = useRouter();
    return { router };
  },
  data() {
    return {
      showConfirmationModal: false,
      isResolving: false,
    };
  },
  computed: {
    ...mapGetters({
      conversationAttributes: 'conversationAttributes/getConversationParams',
      canUserEndConversation: 'appConfig/getCanUserEndConversation',
    }),
    canLeaveConversation() {
      return [
        CONVERSATION_STATUS.OPEN,
        CONVERSATION_STATUS.SNOOZED,
        CONVERSATION_STATUS.PENDING,
      ].includes(this.conversationStatus);
    },
    isIframe() {
      return IFrameHelper.isIFrame();
    },
    isRNWebView() {
      return RNHelper.isRNWebView();
    },
    showHeaderActions() {
      return this.isIframe || this.isRNWebView || this.hasWidgetOptions;
    },
    conversationStatus() {
      return this.conversationAttributes.status;
    },
    hasWidgetOptions() {
      return this.showPopoutButton || this.conversationStatus === 'open';
    },
  },
  methods: {
    popoutWindow() {
      this.closeWindow();
      const {
        location: { origin },
        chatwootWebChannel: { websiteToken },
        authToken,
      } = window;
      popoutChatWindow(
        origin,
        websiteToken,
        this.$root.$i18n.locale,
        authToken
      );
    },
    closeWindow() {
      if (IFrameHelper.isIFrame()) {
        IFrameHelper.sendMessage({ event: 'closeWindow' });
      } else if (RNHelper.isRNWebView) {
        RNHelper.sendMessage({ type: 'close-widget' });
      }
    },
    onEndConversationClick() {
      this.showConfirmationModal = true;
    },
    closeConfirmationModal() {
      this.showConfirmationModal = false;
    },
    async confirmEndConversation() {
      if (this.isResolving) return;
      this.isResolving = true;
      try {
        await this.$store.dispatch('conversation/resolveConversation');
        this.$store.dispatch('conversation/clearConversations');
        this.$store.dispatch(
          'conversationAttributes/clearConversationAttributes'
        );
        this.showConfirmationModal = false;
        const router = this.router || this.$router;
        if (router) {
          await router.replace({ name: 'home' });
        }
      } finally {
        this.isResolving = false;
      }
    },
    resolveConversation() {
      this.onEndConversationClick();
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div v-if="showHeaderActions" class="actions flex items-center gap-3">
    <button
      v-if="
        canLeaveConversation &&
        canUserEndConversation &&
        hasEndConversationEnabled &&
        showEndConversationButton
      "
      class="button transparent compact"
      :title="$t('END_CONVERSATION')"
      @click="onEndConversationClick"
    >
      <FluentIcon icon="sign-out" size="22" class="text-n-slate-12" />
    </button>
    <button
      v-if="showPopoutButton"
      class="button transparent compact new-window--button"
      @click="popoutWindow"
    >
      <FluentIcon icon="open" size="22" class="text-n-slate-12" />
    </button>
    <button
      class="button transparent compact close-button"
      :class="{
        'rn-close-button': isRNWebView,
      }"
      @click="closeWindow"
    >
      <FluentIcon icon="dismiss" size="24" class="text-n-slate-12" />
    </button>

    <Teleport to="body">
      <div
        v-if="showConfirmationModal"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs"
      >
        <div
          class="bg-n-background dark:bg-n-solid-2 rounded-2xl shadow-2xl max-w-xs w-full p-5 border border-n-container text-center"
        >
          <div
            class="w-12 h-12 rounded-full bg-n-ruby-3 dark:bg-n-ruby-4 mx-auto flex items-center justify-center mb-3 text-n-ruby-9"
          >
            <FluentIcon icon="sign-out" size="24" class="text-n-ruby-9" />
          </div>
          <h3 class="text-base font-semibold text-n-slate-12 mb-1">
            {{ $t('END_CONVERSATION_CONFIRMATION.TITLE') }}
          </h3>
          <p class="text-xs text-n-slate-11 mb-5 leading-relaxed">
            {{ $t('END_CONVERSATION_CONFIRMATION.MESSAGE') }}
          </p>
          <div class="flex items-center gap-2">
            <button
              type="button"
              class="flex-1 py-2.5 px-3 rounded-lg text-xs font-medium text-n-slate-12 bg-n-slate-3 hover:bg-n-slate-4 dark:bg-n-solid-3 dark:hover:bg-n-solid-4 transition-colors"
              @click="closeConfirmationModal"
            >
              {{ $t('END_CONVERSATION_CONFIRMATION.CANCEL') }}
            </button>
            <button
              type="button"
              class="flex-1 py-2.5 px-3 rounded-lg text-xs font-semibold text-white bg-n-ruby-9 hover:bg-n-ruby-10 active:brightness-90 transition-all shadow-md disabled:opacity-50"
              :disabled="isResolving"
              @click="confirmEndConversation"
            >
              <span v-if="!isResolving">
                {{ $t('END_CONVERSATION_CONFIRMATION.CONFIRM') }}
              </span>
              <span v-else class="inline-flex items-center justify-center">
                <Spinner size="tiny" />
              </span>
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped lang="scss">
.actions {
  .close-button {
    display: none;
  }

  .rn-close-button {
    display: block !important;
  }
}
</style>
