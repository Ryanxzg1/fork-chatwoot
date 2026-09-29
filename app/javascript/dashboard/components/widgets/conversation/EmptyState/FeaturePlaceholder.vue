<script>
import Hotkey from 'dashboard/components/base/Hotkey.vue';
import { getModifierKey } from 'dashboard/composables/utils/useKbd';

export default {
  components: {
    Hotkey,
  },
  computed: {
    modKey() {
      return getModifierKey();
    },
    keyShortcuts() {
      return [
        {
          keys: [this.modKey, 'K'],
          description: this.$t('CONVERSATION.EMPTY_STATE.CMD_BAR'),
        },
        {
          keys: [this.modKey, '/'],
          description: this.$t('CONVERSATION.EMPTY_STATE.KEYBOARD_SHORTCUTS'),
        },
        {
          keys: ['Alt', 'J / K'],
          description: this.$t('CONVERSATION.EMPTY_STATE.SHORTCUTS.NAVIGATE'),
        },
        {
          keys: ['Alt', 'E'],
          description: this.$t('CONVERSATION.EMPTY_STATE.SHORTCUTS.RESOLVE'),
        },
        {
          keys: ['Alt', 'P'],
          description: this.$t(
            'CONVERSATION.EMPTY_STATE.SHORTCUTS.PRIVATE_NOTE'
          ),
        },
      ];
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col w-full max-w-sm p-3.5 rounded-xl border border-n-weak/80 bg-n-surface-1 shadow-sm mt-2 text-start"
  >
    <div
      class="text-xxs font-semibold uppercase tracking-wider text-n-slate-10 mb-2.5 px-1"
    >
      {{ $t('CONVERSATION.EMPTY_STATE.SHORTCUTS.TITLE') }}
    </div>
    <div class="flex flex-col gap-1.5 w-full">
      <div
        v-for="shortcut in keyShortcuts"
        :key="shortcut.description"
        class="flex items-center justify-between py-1 px-1.5 rounded-lg hover:bg-n-alpha-1 transition-colors text-xs"
      >
        <span class="text-n-slate-11 font-medium truncate me-2">
          {{ shortcut.description }}
        </span>
        <div class="flex items-center gap-1 shrink-0">
          <Hotkey
            v-for="(key, index) in shortcut.keys"
            :key="index"
            custom-class="h-5 min-w-[20px] px-1 text-xxs font-medium text-n-slate-12 outline outline-n-container outline-1 bg-n-alpha-3"
          >
            {{ key }}
          </Hotkey>
        </div>
      </div>
    </div>
  </div>
</template>
