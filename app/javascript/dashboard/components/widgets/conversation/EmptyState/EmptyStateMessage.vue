<script>
import { mapGetters } from 'vuex';
import FeaturePlaceholder from './FeaturePlaceholder.vue';

export default {
  components: { FeaturePlaceholder },
  props: {
    message: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
    }),
    currentUserName() {
      return this.currentUser?.name?.split(' ')[0] || 'there';
    },
    greetingText() {
      const hour = new Date().getHours();
      const name = this.currentUserName;

      if (hour >= 5 && hour < 12) {
        return this.$t('CONVERSATION.EMPTY_STATE.GREETING_MORNING', { name });
      }
      if (hour >= 12 && hour < 18) {
        return this.$t('CONVERSATION.EMPTY_STATE.GREETING_AFTERNOON', { name });
      }
      return this.$t('CONVERSATION.EMPTY_STATE.GREETING_EVENING', { name });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col items-center justify-center h-full max-w-lg mx-auto px-4 text-center select-none"
  >
    <img
      class="mb-4 w-28 hidden dark:block opacity-90 transition-transform duration-300 hover:scale-105"
      src="dashboard/assets/images/no-chat-dark.svg"
      alt="No Chat dark"
    />
    <img
      class="mb-4 w-28 block dark:hidden opacity-90 transition-transform duration-300 hover:scale-105"
      src="dashboard/assets/images/no-chat.svg"
      alt="No Chat"
    />
    <h2 class="text-base font-semibold text-n-slate-12 tracking-tight mb-1">
      {{ greetingText }}
    </h2>
    <p class="text-xs text-n-slate-11 max-w-sm mb-4 leading-relaxed">
      {{ message }}
    </p>

    <!-- Cmd bar, keyboard shortcuts placeholder -->
    <FeaturePlaceholder />
  </div>
</template>
