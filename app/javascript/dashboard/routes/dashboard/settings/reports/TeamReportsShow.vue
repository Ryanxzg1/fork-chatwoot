<script setup>
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';

import WootReports from './components/WootReports.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const store = useStore();
const team = useFunctionGetter('teams/getTeamById', route.params.id);
const isLoading = ref(true);
const fetchError = ref(false);

onMounted(async () => {
  try {
    await store.dispatch('teams/get');
  } catch {
    fetchError.value = true;
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <WootReports
    v-if="team.id"
    :key="team.id"
    type="team"
    getter-key="teams/getTeams"
    action-key="teams/get"
    :selected-item="team"
    :download-button-label="$t('TEAM_REPORTS.DOWNLOAD_TEAM_REPORTS')"
    :report-title="team.name || $t('TEAM_REPORTS.HEADER')"
    :back-url="{ name: 'team_reports_index' }"
    has-back-button
  />
  <div v-else-if="isLoading" class="w-full py-20">
    <Spinner class="mx-auto" />
  </div>
  <div v-else-if="fetchError" class="w-full py-20 text-center text-n-slate-11">
    {{ $t('REPORT.DATA_FETCHING_FAILED') }}
  </div>
  <div v-else class="w-full py-20 text-center text-n-slate-11">
    {{ $t('REPORT.TEAM_NOT_FOUND') }}
  </div>
</template>
