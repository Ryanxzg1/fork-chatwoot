<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ReportMetricCard from './ReportMetricCard.vue';
import ReportsAPI from 'dashboard/api/reports';

const props = defineProps({
  filters: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const isLoading = ref(false);
const conversationCount = ref('0');
const messageCount = ref('0');
const resolutionRate = ref('0');
const handoffRate = ref('0');

const dropOffRate = computed(() => {
  const res = Number(resolutionRate.value) || 0;
  const handoff = Number(handoffRate.value) || 0;
  const totalAccounted = res + handoff;
  if (totalAccounted >= 100) return '0';
  return String(Math.max(0, 100 - totalAccounted));
});

const numResolutionRate = computed(() => Number(resolutionRate.value) || 0);
const numHandoffRate = computed(() => Number(handoffRate.value) || 0);
const numDropOffRate = computed(() => Number(dropOffRate.value) || 0);
const hasBotConversations = computed(
  () =>
    conversationCount.value !== '0' &&
    conversationCount.value !== 0 &&
    conversationCount.value !== ''
);

const formatToPercent = value => {
  if (value === null || value === undefined || value === '') return '--';
  return `${value}%`;
};

const fetchMetrics = async () => {
  if (!props.filters.to || !props.filters.from) {
    return;
  }
  isLoading.value = true;
  try {
    const response = await ReportsAPI.getBotMetrics(props.filters);
    conversationCount.value =
      response.data.conversation_count?.toLocaleString() ?? '0';
    messageCount.value = response.data.message_count?.toLocaleString() ?? '0';
    resolutionRate.value = response.data.resolution_rate?.toString() ?? '0';
    handoffRate.value = response.data.handoff_rate?.toString() ?? '0';
  } catch {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  } finally {
    isLoading.value = false;
  }
};

watch(() => props.filters, fetchMetrics, { deep: true });

onMounted(fetchMetrics);
</script>

<template>
  <div
    class="relative flex flex-wrap mx-0 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5"
  >
    <div
      v-if="isLoading"
      class="absolute inset-0 bg-n-solid-2/80 backdrop-blur-[2px] z-10 flex items-center justify-center rounded-xl"
    >
      <Spinner />
    </div>
    <ReportMetricCard
      :label="$t('BOT_REPORTS.METRIC.TOTAL_CONVERSATIONS.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.TOTAL_CONVERSATIONS.TOOLTIP')"
      :value="conversationCount"
      class="flex-1"
    />
    <ReportMetricCard
      :label="$t('BOT_REPORTS.METRIC.TOTAL_RESPONSES.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.TOTAL_RESPONSES.TOOLTIP')"
      :value="messageCount"
      class="flex-1"
    />
    <ReportMetricCard
      :label="$t('BOT_REPORTS.METRIC.RESOLUTION_RATE.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.RESOLUTION_RATE.TOOLTIP')"
      :value="formatToPercent(resolutionRate)"
      class="flex-1"
    />
    <ReportMetricCard
      :label="$t('BOT_REPORTS.METRIC.HANDOFF_RATE.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.HANDOFF_RATE.TOOLTIP')"
      :value="formatToPercent(handoffRate)"
      class="flex-1"
    />
    <ReportMetricCard
      :label="$t('BOT_REPORTS.METRIC.DROP_OFF_RATE.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.DROP_OFF_RATE.TOOLTIP')"
      :value="formatToPercent(dropOffRate)"
      class="flex-1"
    />

    <div
      v-if="hasBotConversations"
      class="w-full mt-6 pt-5 border-t border-n-weak/50 flex flex-col gap-2.5"
    >
      <div
        class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between"
      >
        <span class="text-xs font-medium text-n-slate-11">
          {{ $t('BOT_REPORTS.FUNNEL.TITLE') }}
        </span>
        <div class="flex flex-wrap items-center gap-4 text-xs">
          <div class="flex items-center gap-1.5">
            <span class="size-2.5 rounded-full bg-n-teal-9" />
            <span class="text-n-slate-11">
              {{ $t('BOT_REPORTS.FUNNEL.BOT_RESOLVED') }}
            </span>
            <span class="font-medium text-n-slate-12 tabular-nums">
              {{ `(${numResolutionRate}%)` }}
            </span>
          </div>
          <div class="flex items-center gap-1.5">
            <span class="size-2.5 rounded-full bg-n-blue-9" />
            <span class="text-n-slate-11">
              {{ $t('BOT_REPORTS.FUNNEL.AGENT_HANDOFF') }}
            </span>
            <span class="font-medium text-n-slate-12 tabular-nums">
              {{ `(${numHandoffRate}%)` }}
            </span>
          </div>
          <div class="flex items-center gap-1.5">
            <span class="size-2.5 rounded-full bg-n-slate-8" />
            <span class="text-n-slate-11">
              {{ $t('BOT_REPORTS.FUNNEL.DROPPED_OFF') }}
            </span>
            <span class="font-medium text-n-slate-12 tabular-nums">
              {{ `(${numDropOffRate}%)` }}
            </span>
          </div>
        </div>
      </div>
      <div class="h-2.5 w-full bg-n-alpha-2 rounded-full overflow-hidden flex">
        <div
          v-if="numResolutionRate > 0"
          class="h-full bg-n-teal-9 transition-all duration-300"
          :style="{ width: `${numResolutionRate}%` }"
        />
        <div
          v-if="numHandoffRate > 0"
          class="h-full bg-n-blue-9 transition-all duration-300"
          :style="{ width: `${numHandoffRate}%` }"
        />
        <div
          v-if="numDropOffRate > 0"
          class="h-full bg-n-slate-8 transition-all duration-300"
          :style="{ width: `${numDropOffRate}%` }"
        />
      </div>
    </div>
  </div>
</template>
