<script setup>
import ReportHeader from './components/ReportHeader.vue';
import ConversationHeatmapContainer from './components/heatmaps/ConversationHeatmapContainer.vue';
import ResolutionHeatmapContainer from './components/heatmaps/ResolutionHeatmapContainer.vue';
import AgentLiveReportContainer from './components/AgentLiveReportContainer.vue';
import TeamLiveReportContainer from './components/TeamLiveReportContainer.vue';
import StatsLiveReportsContainer from './components/StatsLiveReportsContainer.vue';
</script>

<template>
  <ReportHeader :header-title="$t('OVERVIEW_REPORTS.HEADER')" />
  <div class="grid grid-cols-1 gap-4 pb-6 xl:grid-cols-2 2xl:gap-6">
    <StatsLiveReportsContainer class="min-w-0 xl:col-span-2" />
    <ConversationHeatmapContainer
      class="min-w-0 xl:col-span-2 2xl:col-span-1"
    />
    <ResolutionHeatmapContainer class="min-w-0 xl:col-span-2 2xl:col-span-1" />
    <AgentLiveReportContainer class="min-w-0" />
    <TeamLiveReportContainer class="min-w-0" />
  </div>
</template>
