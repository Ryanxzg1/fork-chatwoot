<script>
import V4Button from 'dashboard/components-next/button/Button.vue';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SLAMetrics from './components/SLA/SLAMetrics.vue';
import SLATable from './components/SLA/SLATable.vue';
import SLAReportFilters from './components/SLA/SLAReportFilters.vue';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import ReportHeader from './components/ReportHeader.vue';
export default {
  name: 'SLAReports',
  components: {
    V4Button,
    ReportHeader,
    SLAMetrics,
    SLATable,
    SLAReportFilters,
  },
  data() {
    return {
      pageNumber: 1,
      isDownloading: false,
      activeFilter: {
        from: 0,
        to: 0,
        assigned_agent_id: null,
        inbox_id: null,
        team_id: null,
        sla_policy_id: null,
        label_list: null,
      },
    };
  },
  computed: {
    ...mapGetters({
      slaReports: 'slaReports/getAll',
      slaMetrics: 'slaReports/getMetrics',
      slaMeta: 'slaReports/getMeta',
      uiFlags: 'slaReports/getUIFlags',
    }),
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('inboxes/get');
    this.$store.dispatch('teams/get');
    this.$store.dispatch('labels/get');
    this.$store.dispatch('sla/get');
  },
  methods: {
    fetchSLAReports({ pageNumber } = {}) {
      this.$store.dispatch('slaReports/get', {
        page: pageNumber || this.pageNumber,
        ...this.activeFilter,
      });
    },
    fetchSLAMetrics() {
      this.$store.dispatch('slaReports/getMetrics', this.activeFilter);
    },
    onPageChange(pageNumber) {
      this.fetchSLAReports({ pageNumber });
    },
    onFilterChange(params) {
      this.activeFilter = params;
      this.fetchSLAReports();
      this.fetchSLAMetrics();
    },
    async downloadReports() {
      const type = 'sla';
      this.isDownloading = true;
      try {
        await this.$store.dispatch('slaReports/download', {
          fileName: generateFileName({ type, to: this.activeFilter.to }),
          ...this.activeFilter,
        });
      } catch (error) {
        useAlert(this.$t('SLA_REPORTS.DOWNLOAD_FAILED'));
      } finally {
        this.isDownloading = false;
      }
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="$t('SLA_REPORTS.HEADER')">
    <V4Button
      :label="$t('SLA_REPORTS.DOWNLOAD_SLA_REPORTS')"
      icon="i-ph-download-simple"
      size="sm"
      :is-loading="isDownloading"
      :disabled="isDownloading"
      @click="downloadReports"
    />
  </ReportHeader>
  <div class="flex flex-col flex-1 gap-6">
    <SLAReportFilters @filter-change="onFilterChange" />
    <SLAMetrics
      :hit-rate="slaMetrics.hitRate"
      :no-of-breaches="slaMetrics.numberOfSLAMisses"
      :no-of-conversations="slaMetrics.numberOfConversations"
      :is-loading="uiFlags.isFetchingMetrics"
    />
    <SLATable
      :sla-reports="slaReports"
      :is-loading="uiFlags.isFetching"
      :current-page="Number(slaMeta.currentPage)"
      :total-count="Number(slaMeta.count)"
      @page-change="onPageChange"
    />
  </div>
</template>
