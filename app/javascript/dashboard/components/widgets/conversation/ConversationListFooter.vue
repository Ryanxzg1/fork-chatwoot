<script setup>
defineProps({
  statusLabel: {
    type: String,
    default: '',
  },
  count: {
    type: Number,
    default: 0,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['refresh']);
</script>

<template>
  <footer
    class="flex items-center justify-between px-4 py-4 border-t border-n-weak bg-n-surface-1 text-xs select-none flex-shrink-0"
  >
    <div
      class="flex items-center gap-1.5 min-w-0 truncate text-n-slate-12 font-medium"
    >
      <span class="truncate">
        {{ $t('CHAT_LIST.FOOTER.CHAT_COUNT', { status: statusLabel, count }) }}
      </span>
    </div>
    <button
      type="button"
      class="inline-flex items-center gap-1.5 h-7 px-2.5 rounded-lg text-xs font-medium text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors disabled:opacity-50 disabled:pointer-events-none shrink-0"
      :disabled="isLoading"
      :title="$t('CHAT_LIST.FOOTER.REFRESH_TOOLTIP')"
      :aria-label="$t('CHAT_LIST.FOOTER.REFRESH_TOOLTIP')"
      @click="emit('refresh')"
    >
      <span
        class="i-lucide-refresh-cw size-3.5"
        :class="{ 'animate-spin': isLoading }"
      />
      <span>{{ $t('CHAT_LIST.FOOTER.REFRESH_LABEL') }}</span>
    </button>
  </footer>
</template>
