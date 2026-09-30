<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import UserAvatarWithName from 'dashboard/components/widgets/UserAvatarWithName.vue';
import CardLabels from 'dashboard/components/widgets/conversation/conversationCardComponents/CardLabels.vue';
import { dynamicTime } from 'shared/helpers/timeHelper';
import SLAViewDetails from './SLAViewDetails.vue';
const props = defineProps({
  slaName: {
    type: String,
    required: true,
  },
  conversationId: {
    type: Number,
    required: true,
  },
  conversation: {
    type: Object,
    required: true,
  },
  slaEvents: {
    type: Array,
    default: () => [],
  },
});

const route = useRoute();

const conversationLabels = computed(() => {
  return props.conversation.labels
    ? props.conversation.labels.split(',').map(item => item.trim())
    : [];
});

const conversationPath = computed(() => {
  const accountId = route.params.accountId;
  return `/app/accounts/${accountId}/conversations/${props.conversationId}`;
});

const hasFrtBreach = computed(() =>
  props.slaEvents.some(event => event.event_type === 'frt')
);
const hasNrtBreach = computed(() =>
  props.slaEvents.some(event => event.event_type === 'nrt')
);
const hasRtBreach = computed(() =>
  props.slaEvents.some(event => event.event_type === 'rt')
);

const latestBreachEvent = computed(() => {
  if (!props.slaEvents.length) return null;
  return [...props.slaEvents].sort(
    (a, b) => (Number(b.created_at) || 0) - (Number(a.created_at) || 0)
  )[0];
});

const latestBreachAgo = computed(() => {
  if (!latestBreachEvent.value?.created_at) return '';
  return dynamicTime(latestBreachEvent.value.created_at);
});
</script>

<template>
  <div
    class="grid items-center content-center w-full min-h-16 grid-cols-12 gap-4 px-6 py-2 border-b last:border-b-0 last:rounded-b-xl border-n-weak"
  >
    <div
      class="flex items-center gap-2 col-span-4 px-0 py-1 text-sm tracking-[0.5] text-n-slate-12 rtl:text-right"
    >
      <a
        :href="conversationPath"
        target="_blank"
        rel="noopener noreferrer nofollow"
        class="text-n-slate-12 font-medium hover:underline hover:text-n-brand"
      >
        {{ `#${conversationId}` }}
      </a>
      <span class="text-n-slate-11">
        {{ $t('SLA_REPORTS.WITH') }}
      </span>
      <span class="capitalize truncate text-n-slate-12">{{
        conversation.contact.name
      }}</span>
      <CardLabels
        v-if="conversationLabels.length"
        class="w-[50%]"
        :conversation-id="conversationId"
        :conversation-labels="conversationLabels"
      />
    </div>
    <div class="flex flex-col justify-center col-span-2 gap-1 py-1">
      <div class="flex items-center gap-1.5 flex-wrap">
        <span
          v-if="hasFrtBreach"
          class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-semibold bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-6/40"
        >
          {{ $t('SLA_REPORTS.BREACH_TYPES.FRT') }}
        </span>
        <span
          v-if="hasNrtBreach"
          class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-semibold bg-n-amber-3 text-n-amber-11 border border-n-amber-6/40"
        >
          {{ $t('SLA_REPORTS.BREACH_TYPES.NRT') }}
        </span>
        <span
          v-if="hasRtBreach"
          class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-semibold bg-n-iris-3 text-n-iris-11 border border-n-iris-6/40"
        >
          {{ $t('SLA_REPORTS.BREACH_TYPES.RESOLUTION') }}
        </span>
      </div>
      <span v-if="latestBreachAgo" class="text-xs text-n-slate-10">
        {{ latestBreachAgo }}
      </span>
    </div>
    <div
      class="flex items-center capitalize py-1 px-0 text-sm tracking-[0.5] text-n-slate-12 text-left rtl:text-right col-span-2"
    >
      {{ slaName }}
    </div>
    <div class="flex items-center col-span-2 gap-2">
      <UserAvatarWithName
        v-if="conversation.assignee"
        :user="conversation.assignee"
      />
      <span v-else class="text-n-slate-11"> --- </span>
    </div>
    <SLAViewDetails :sla-events="slaEvents" />
  </div>
</template>
