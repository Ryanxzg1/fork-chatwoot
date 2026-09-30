<script setup>
import { ref, watch, onMounted } from 'vue';
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
  </div>
</template>
