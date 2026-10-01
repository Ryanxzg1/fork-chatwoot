<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { OVERVIEW_METRICS } from '../constants';
import { useToggle } from '@vueuse/core';

import MetricCard from './overview/MetricCard.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';
import { useAccount } from 'dashboard/composables/useAccount';
import { useUISettings } from 'dashboard/composables/useUISettings';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';
const { t } = useI18n();

const route = useRoute();
const router = useRouter();
const { accountId } = useAccount();
const { uiSettings, updateUISettings } = useUISettings();

const uiFlags = useMapGetter('getOverviewUIFlags');
const agentStatus = useMapGetter('agents/getAgentStatus');
const accountConversationMetric = useMapGetter('getAccountConversationMetric');
const store = useStore();

const accounti18nKey = 'OVERVIEW_REPORTS.ACCOUNT_CONVERSATIONS';
const teams = useMapGetter('teams/getTeams');

const teamMenuList = computed(() => {
  return [
    { label: t('OVERVIEW_REPORTS.TEAM_CONVERSATIONS.ALL_TEAMS'), value: null },
    ...teams.value.map(team => ({ label: team.name, value: team.id })),
  ];
});

const agentStatusMetrics = computed(() => {
  let metric = {};
  Object.keys(agentStatus.value).forEach(key => {
    const metricName = t(
      `OVERVIEW_REPORTS.AGENT_STATUS.${OVERVIEW_METRICS[key]}`
    );
    metric[metricName] = agentStatus.value[key];
  });
  return metric;
});

const conversationMetricItems = computed(() => {
  const metricData = accountConversationMetric.value || {};
  const order = ['open', 'unattended', 'unassigned', 'pending'];
  return order.map(key => {
    const rawValue = metricData[key];
    const value =
      typeof rawValue === 'number' && Number.isFinite(rawValue) ? rawValue : 0;
    return {
      key,
      name: t(`${accounti18nKey}.${OVERVIEW_METRICS[key]}`),
      value,
    };
  });
});

const selectedTeam = ref(null);
const selectedTeamLabel = computed(() => {
  const team =
    teamMenuList.value.find(
      menuItem => menuItem.value === selectedTeam.value
    ) || {};
  return team.label;
});
const fetchData = () => {
  const params = {};
  if (selectedTeam.value) {
    params.team_id = selectedTeam.value;
  }
  store.dispatch('fetchAccountConversationMetric', params);
};

const handleMetricClick = key => {
  const currentAccountId = accountId.value || route.params.accountId;
  if (!currentAccountId) return;

  const currentFilters = uiSettings.value?.conversations_filter_by || {};
  const targetRoute = selectedTeam.value
    ? {
        name: 'team_conversations',
        params: { accountId: currentAccountId, teamId: selectedTeam.value },
      }
    : {
        name: 'home',
        params: { accountId: currentAccountId },
      };

  if (key === 'unattended') {
    router.push({
      name: 'conversation_unattended',
      params: { accountId: currentAccountId },
    });
  } else if (key === 'pending') {
    store.dispatch('setChatStatusFilter', 'pending');
    updateUISettings({
      conversations_filter_by: {
        ...currentFilters,
        status: 'pending',
      },
    });
    router.push(targetRoute);
  } else {
    // 'open' or 'unassigned'
    store.dispatch('setChatStatusFilter', 'open');
    updateUISettings({
      conversations_filter_by: {
        ...currentFilters,
        status: 'open',
      },
    });
    router.push(targetRoute);
  }
};

const { startRefetching } = useLiveRefresh(fetchData);
const [showDropdown, toggleDropdown] = useToggle();

const handleAction = ({ value }) => {
  toggleDropdown(false);
  selectedTeam.value = value;
  fetchData();
};

onMounted(() => {
  fetchData();
  startRefetching();
});
</script>

<template>
  <div class="flex flex-col items-center md:flex-row gap-4">
    <div
      class="flex-1 w-full max-w-full md:w-[65%] md:max-w-[65%] conversation-metric"
    >
      <MetricCard
        :header="t(`${accounti18nKey}.HEADER`)"
        :is-loading="uiFlags.isFetchingAccountConversationMetric"
        :loading-message="t(`${accounti18nKey}.LOADING_MESSAGE`)"
      >
        <template v-if="teams.length" #control>
          <div
            v-on-clickaway="() => toggleDropdown(false)"
            class="relative flex items-center group z-50"
          >
            <Button
              sm
              slate
              faded
              :label="selectedTeamLabel"
              class="capitalize rounded-md group-hover:bg-n-alpha-2"
              @click="toggleDropdown()"
            />
            <DropdownMenu
              v-if="showDropdown"
              :menu-items="teamMenuList"
              class="mt-1 ltr:right-0 rtl:left-0 xl:ltr:right-0 xl:rtl:left-0 top-full"
              label-class="capitalize"
              @action="handleAction($event)"
            />
          </div>
        </template>
        <div
          v-for="item in conversationMetricItems"
          :key="item.key"
          tabindex="0"
          role="link"
          class="flex-1 min-w-0 pb-2 p-2.5 rounded-lg border border-transparent hover:border-n-weak hover:bg-n-alpha-1 cursor-pointer transition-all focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand group"
          @click="handleMetricClick(item.key)"
          @keydown.enter="handleMetricClick(item.key)"
          @keydown.space.prevent="handleMetricClick(item.key)"
        >
          <div class="flex items-center justify-between gap-1">
            <h3
              class="text-base text-n-slate-11 group-hover:text-n-slate-12 transition-colors truncate"
            >
              {{ item.name }}
            </h3>
            <Icon
              icon="i-lucide-arrow-up-right"
              class="size-3.5 text-n-slate-8 opacity-0 group-hover:opacity-100 group-hover:text-n-brand shrink-0 transition-opacity"
            />
          </div>
          <div class="flex items-baseline gap-2 mt-1">
            <p
              class="text-3xl font-semibold mb-0 transition-colors tabular-nums"
              :class="
                item.key === 'unattended' && item.value > 0
                  ? 'text-n-amber-11'
                  : 'text-n-slate-12'
              "
            >
              {{ item.value.toLocaleString() }}
            </p>
          </div>
        </div>
      </MetricCard>
    </div>
    <div class="flex-1 w-full max-w-full md:w-[35%] md:max-w-[35%]">
      <MetricCard :header="$t('OVERVIEW_REPORTS.AGENT_STATUS.HEADER')">
        <div
          v-for="(metric, name, index) in agentStatusMetrics"
          :key="index"
          class="flex-1 min-w-0 pb-2 p-2.5"
        >
          <h3 class="text-base text-n-slate-11 truncate">
            {{ name }}
          </h3>
          <p
            class="text-n-slate-12 text-3xl font-semibold mb-0 mt-1 tabular-nums"
          >
            {{ Number.isFinite(metric) ? metric.toLocaleString() : metric }}
          </p>
        </div>
      </MetricCard>
    </div>
  </div>
</template>
