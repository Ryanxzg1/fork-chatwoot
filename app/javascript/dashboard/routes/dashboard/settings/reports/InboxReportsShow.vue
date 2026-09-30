<script setup>
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';

import WootReports from './components/WootReports.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const store = useStore();
const inbox = useFunctionGetter('inboxes/getInboxById', route.params.id);
const isLoading = ref(true);
const fetchError = ref(false);

onMounted(async () => {
  try {
    const result = await store.dispatch('inboxes/get');
    fetchError.value = result === false;
  } catch {
    fetchError.value = true;
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <WootReports
    v-if="inbox.id"
    :key="inbox.id"
    type="inbox"
    getter-key="inboxes/getInboxes"
    action-key="inboxes/get"
    :selected-item="inbox"
    :download-button-label="$t('INBOX_REPORTS.DOWNLOAD_INBOX_REPORTS')"
    :report-title="inbox.name || $t('INBOX_REPORTS.HEADER')"
    :back-url="{ name: 'inbox_reports_index' }"
    has-back-button
  />
  <div v-else-if="isLoading" class="w-full py-20">
    <Spinner class="mx-auto" />
  </div>
  <div v-else-if="fetchError" class="w-full py-20 text-center text-n-slate-11">
    {{ $t('REPORT.DATA_FETCHING_FAILED') }}
  </div>
  <div v-else class="w-full py-20 text-center text-n-slate-11">
    {{ $t('REPORT.INBOX_NOT_FOUND') }}
  </div>
</template>
