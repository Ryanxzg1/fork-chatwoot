<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  activeStatus: {
    type: String,
    default: wootConstants.STATUS_TYPE.OPEN,
  },
});

const emit = defineEmits(['statusChange']);

const { t } = useI18n();

const statusItems = computed(() => [
  {
    key: wootConstants.STATUS_TYPE.OPEN,
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT'),
    dotClass: 'bg-emerald-500 dark:bg-emerald-400',
  },
  {
    key: wootConstants.STATUS_TYPE.PENDING,
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'),
    dotClass: 'bg-amber-500 dark:bg-amber-400',
  },
  {
    key: wootConstants.STATUS_TYPE.SNOOZED,
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'),
    dotClass: 'bg-indigo-500 dark:bg-indigo-400',
  },
  {
    key: wootConstants.STATUS_TYPE.RESOLVED,
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved.TEXT'),
    dotClass: 'bg-slate-400 dark:bg-slate-500',
  },
  {
    key: wootConstants.STATUS_TYPE.ALL,
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.all.TEXT'),
    dotClass: 'bg-blue-500 dark:bg-blue-400',
  },
]);

const selectStatus = key => {
  if (key !== props.activeStatus) {
    emit('statusChange', key);
  }
};
</script>

<template>
  <div
    class="flex items-center gap-1.5 px-3 py-1.5 border-b border-n-weak overflow-x-auto no-scrollbar"
    role="tablist"
    :aria-label="$t('CHAT_LIST.CHAT_SORT.STATUS')"
  >
    <button
      v-for="status in statusItems"
      :key="status.key"
      type="button"
      role="tab"
      :aria-selected="activeStatus === status.key"
      class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-full transition-all shrink-0 cursor-pointer select-none focus:outline-none focus:ring-1 focus:ring-n-brand"
      :class="
        activeStatus === status.key
          ? 'bg-n-slate-12 text-n-slate-1 dark:bg-n-slate-1 dark:text-n-slate-12 font-medium shadow-sm'
          : 'bg-n-alpha-1 hover:bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12 font-normal'
      "
      @click="selectStatus(status.key)"
    >
      <span class="size-1.5 rounded-full shrink-0" :class="status.dotClass" />
      <span>{{ status.label }}</span>
    </button>
  </div>
</template>
