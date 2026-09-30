<script setup>
import { h, ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { provideSidebarContext, useRoutePolicy } from './provider';
import { useAccount } from 'dashboard/composables/useAccount';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useSidebarKeyboardShortcuts } from './useSidebarKeyboardShortcuts';
import { vOnClickOutside } from '@vueuse/components';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useWindowSize } from '@vueuse/core';

import Icon from 'next/icon/Icon.vue';
import SidebarGroup from './SidebarGroup.vue';
import SidebarProfileMenu from './SidebarProfileMenu.vue';
import SidebarChangelogButton from './SidebarChangelogButton.vue';
import ChannelLeaf from './ChannelLeaf.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import EmojiIcon from 'next/emoji-icon-picker/EmojiIcon.vue';
import {
  SIDEBAR_SORT_SECTIONS,
  getSidebarSortOptions,
  resolveSidebarSort,
  sortSidebarItems,
} from 'dashboard/helper/sidebarSort';

const props = defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'closeKeyShortcutModal',
  'openKeyShortcutModal',
  'closeMobileSidebar',
]);

const { accountScopedRoute, isOnChatwootCloud } = useAccount();
const store = useStore();
const { t } = useI18n();

const isACustomBrandedInstance = useMapGetter(
  'globalConfig/isACustomBrandedInstance'
);
const route = useRoute();
const router = useRouter();
const { isAllowed } = useRoutePolicy();

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 768);

const accountId = useMapGetter('getCurrentAccountId');
const currentUserId = useMapGetter('getCurrentUserID');

// PERSISTENCE FOR SUBMENU CARD
const { uiSettings, updateUISettings } = useUISettings();
const isSubmenuCardOpen = computed({
  get: () => uiSettings.value.is_sidebar_submenu_open !== false,
  set: val => updateUISettings({ is_sidebar_submenu_open: val }),
});

const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const hasAdvancedAssignment = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.ADVANCED_ASSIGNMENT
  );
});

const hasConversationUnreadCounts = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.CONVERSATION_UNREAD_COUNTS
  );
});

const hasFilteredUnreadCounts = computed(() => {
  return (
    hasConversationUnreadCounts.value &&
    isFeatureEnabledonAccount.value(
      accountId.value,
      FEATURE_FLAGS.UNREAD_COUNT_FOR_FILTERS
    )
  );
});

const hasDataImport = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.DATA_IMPORT
  );
});

// GETTERS
const inboxes = useMapGetter('inboxes/getInboxes');
const labels = useMapGetter('labels/getLabelsOnSidebar');
const getInboxUnreadCount = useMapGetter(
  'conversationUnreadCounts/getInboxUnreadCount'
);
const getLabelUnreadCount = useMapGetter(
  'conversationUnreadCounts/getLabelUnreadCount'
);
const getTeamUnreadCount = useMapGetter(
  'conversationUnreadCounts/getTeamUnreadCount'
);
const getFolderUnreadCount = useMapGetter(
  'conversationUnreadCounts/getFolderUnreadCount'
);
const teams = useMapGetter('teams/getMyTeams');
const contactCustomViews = useMapGetter('customViews/getContactCustomViews');
const conversationCustomViews = useMapGetter(
  'customViews/getConversationCustomViews'
);
const getSidebarSectionSort = useMapGetter(
  'sidebarSortPreferences/getSectionSort'
);
const notificationsUnreadCount = useMapGetter('notifications/getUnreadCount');
const conversationAllUnreadCount = useMapGetter(
  'conversationUnreadCounts/getAllUnreadCount'
);
const portals = useMapGetter('portals/allPortals');
const hasPortals = computed(() => (portals.value?.length || 0) > 0);

const hasUnread = item => {
  if (item.name === 'Inbox') {
    return Number(notificationsUnreadCount.value) > 0;
  }
  if (item.name === 'Conversation') {
    return Number(conversationAllUnreadCount.value) > 0;
  }
  if (item.children?.length) {
    return item.children.some(child => Number(child.badgeCount) > 0);
  }
  return false;
};

const fetchConversationUnreadCounts = ([currentAccountId, isEnabled]) => {
  if (!currentAccountId) return;

  if (!isEnabled) {
    store.dispatch('conversationUnreadCounts/clear');
    return;
  }

  store.dispatch('conversationUnreadCounts/get');
};

const fetchSidebarSortPreferences = ([currentAccountId, userId]) => {
  if (!currentAccountId || !userId) return;
  store.dispatch('sidebarSortPreferences/initialize');
};

const toggleShortcutModalFn = show => {
  if (show) {
    emit('openKeyShortcutModal');
  } else {
    emit('closeKeyShortcutModal');
  }
};

useSidebarKeyboardShortcuts(toggleShortcutModalFn);

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
  store.dispatch('portals/index');
});

watch([accountId, hasConversationUnreadCounts], fetchConversationUnreadCounts, {
  immediate: true,
});

watch([accountId, currentUserId], fetchSidebarSortPreferences, {
  immediate: true,
});

const hasUnreadCountsForSection = section => {
  if (section === SIDEBAR_SORT_SECTIONS.FOLDERS) {
    return hasFilteredUnreadCounts.value;
  }

  return hasConversationUnreadCounts.value;
};

const getSortOptionsForSection = section =>
  getSidebarSortOptions(section, {
    hasUnreadCounts: hasUnreadCountsForSection(section),
  });

const getSortForSection = section =>
  resolveSidebarSort(section, getSidebarSectionSort.value(section), {
    hasUnreadCounts: hasUnreadCountsForSection(section),
  });

const updateSortPreference = (section, sortBy) => {
  store.dispatch('sidebarSortPreferences/setSectionSort', {
    section,
    sortBy,
  });
};

const buildSortConfig = section => ({
  sortOptions: getSortOptionsForSection(section),
  activeSort: getSortForSection(section),
  onSortChange: sortBy => updateSortPreference(section, sortBy),
});

const sortedFolders = computed(() =>
  sortSidebarItems(conversationCustomViews.value, {
    sortBy: getSortForSection(SIDEBAR_SORT_SECTIONS.FOLDERS),
    labelKey: view => view.name,
    unreadCountKey: view => getFolderUnreadCount.value(view.id),
  })
);

const sortedTeams = computed(() =>
  sortSidebarItems(teams.value, {
    sortBy: getSortForSection(SIDEBAR_SORT_SECTIONS.TEAMS),
    labelKey: team => team.name,
    unreadCountKey: team => getTeamUnreadCount.value(team.id),
  })
);

const sortedInboxes = computed(() =>
  sortSidebarItems(inboxes.value, {
    sortBy: getSortForSection(SIDEBAR_SORT_SECTIONS.CHANNELS),
    labelKey: inbox => inbox.name,
    unreadCountKey: inbox => getInboxUnreadCount.value(inbox.id),
  })
);

const sortedLabels = computed(() =>
  sortSidebarItems(labels.value, {
    sortBy: getSortForSection(SIDEBAR_SORT_SECTIONS.LABELS),
    labelKey: label => label.title,
    unreadCountKey: label => getLabelUnreadCount.value(label.id),
  })
);

const closeMobileSidebar = () => {
  if (!props.isMobileSidebarOpen) return;
  emit('closeMobileSidebar');
};

const newReportRoutes = () => [
  {
    name: 'Reports Agent',
    label: t('SIDEBAR.REPORTS_AGENT'),
    icon: 'i-lucide-users',
    to: accountScopedRoute('agent_reports_index'),
    activeOn: ['agent_reports_show'],
  },
  {
    name: 'Reports Label',
    label: t('SIDEBAR.REPORTS_LABEL'),
    icon: 'i-lucide-tag',
    to: accountScopedRoute('label_reports_index'),
    activeOn: ['label_reports_show'],
  },
  {
    name: 'Reports Inbox',
    label: t('SIDEBAR.REPORTS_INBOX'),
    icon: 'i-lucide-inbox',
    to: accountScopedRoute('inbox_reports_index'),
    activeOn: ['inbox_reports_show'],
  },
  {
    name: 'Reports Team',
    label: t('SIDEBAR.REPORTS_TEAM'),
    icon: 'i-lucide-users-round',
    to: accountScopedRoute('team_reports_index'),
    activeOn: ['team_reports_show'],
  },
];

const reportRoutes = computed(() => newReportRoutes());

const menuItems = computed(() => {
  return [
    {
      name: 'Inbox',
      label: t('SIDEBAR.INBOX'),
      icon: 'i-lucide-inbox',
      to: accountScopedRoute('inbox_view'),
      activeOn: ['inbox_view', 'inbox_view_conversation'],
      getterKeys: {
        count: 'notifications/getUnreadCount',
      },
    },
    {
      name: 'Conversation',
      label: t('SIDEBAR.CONVERSATIONS'),
      icon: 'i-lucide-message-circle',
      to: accountScopedRoute('home'),
      activeOn: [
        'home',
        'inbox_conversation',
        'conversation_through_mentions',
        'conversation_mentions',
        'conversation_through_participating',
        'conversation_participating',
        'conversation_through_unattended',
        'conversation_unattended',
      ],
      getterKeys: {
        count: 'conversationUnreadCounts/getAllUnreadCount',
      },
    },
    {
      name: 'Channels',
      label: t('SIDEBAR.CHANNELS'),
      icon: 'i-lucide-mailbox',
      activeOn: ['conversation_through_inbox'],
      ...buildSortConfig(SIDEBAR_SORT_SECTIONS.CHANNELS),
      collapsible: true,
      showTreeLine: true,
      children: sortedInboxes.value.map(inbox => ({
        name: `${inbox.name}-${inbox.id}`,
        label: inbox.name,
        badgeCount: getInboxUnreadCount.value(inbox.id),
        icon: h(ChannelIcon, { inbox, class: 'size-[16px]' }),
        to: accountScopedRoute('inbox_dashboard', { inbox_id: inbox.id }),
        component: leafProps =>
          h(ChannelLeaf, {
            label: leafProps.label,
            active: leafProps.active,
            inbox,
            badgeCount: leafProps.badgeCount,
          }),
      })),
    },
    {
      name: 'Teams',
      label: t('SIDEBAR.TEAMS'),
      icon: 'i-lucide-users',
      activeOn: ['conversations_through_team'],
      ...buildSortConfig(SIDEBAR_SORT_SECTIONS.TEAMS),
      collapsible: true,
      showTreeLine: true,
      children: sortedTeams.value.map(team => ({
        name: `${team.name}-${team.id}`,
        label: team.name,
        badgeCount: getTeamUnreadCount.value(team.id),
        icon: team.icon
          ? h(EmojiIcon, {
              value: team.icon,
              color: team.icon_color,
              class: 'size-3.5',
            })
          : undefined,
        to: accountScopedRoute('team_conversations', { teamId: team.id }),
      })),
    },
    ...(sortedFolders.value.length
      ? [
          {
            name: 'Folders',
            label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'),
            icon: 'i-lucide-folder',
            activeOn: ['conversations_through_folders'],
            ...buildSortConfig(SIDEBAR_SORT_SECTIONS.FOLDERS),
            collapsible: true,
            showTreeLine: true,
            children: sortedFolders.value.map(view => ({
              name: `${view.name}-${view.id}`,
              label: view.name,
              badgeCount: hasFilteredUnreadCounts.value
                ? getFolderUnreadCount.value(view.id)
                : 0,
              to: accountScopedRoute('folder_conversations', { id: view.id }),
            })),
          },
        ]
      : []),
    ...(sortedLabels.value.length
      ? [
          {
            name: 'Labels',
            label: t('SIDEBAR.LABELS'),
            icon: 'i-lucide-tag',
            activeOn: ['conversations_through_label'],
            ...buildSortConfig(SIDEBAR_SORT_SECTIONS.LABELS),
            collapsible: true,
            showTreeLine: true,
            children: sortedLabels.value.map(label => ({
              name: `${label.title}-${label.id}`,
              label: label.title,
              badgeCount: getLabelUnreadCount.value(label.id),
              icon: h('span', {
                class: `size-[8px] rounded-sm`,
                style: { backgroundColor: label.color },
              }),
              to: accountScopedRoute('label_conversations', {
                label: label.title,
              }),
            })),
          },
        ]
      : []),
    {
      name: 'Contacts',
      label: t('SIDEBAR.CONTACTS'),
      icon: 'i-lucide-contact',
      children: [
        {
          name: 'All Contacts',
          label: t('SIDEBAR.ALL_CONTACTS'),
          to: accountScopedRoute(
            'contacts_dashboard_index',
            {},
            { page: 1, search: undefined }
          ),
          activeOn: ['contacts_dashboard_index', 'contacts_edit'],
        },
        {
          name: 'Active',
          label: t('SIDEBAR.ACTIVE'),
          to: accountScopedRoute('contacts_dashboard_active'),
          activeOn: ['contacts_dashboard_active'],
        },
        {
          name: 'Segments',
          icon: 'i-lucide-group',
          label: t('SIDEBAR.CUSTOM_VIEWS_SEGMENTS'),
          collapsible: true,
          showTreeLine: true,
          children: contactCustomViews.value.map(view => ({
            name: `${view.name}-${view.id}`,
            label: view.name,
            to: accountScopedRoute(
              'contacts_dashboard_segments_index',
              { segmentId: view.id },
              { page: 1 }
            ),
            activeOn: [
              'contacts_dashboard_segments_index',
              'contacts_edit_segment',
            ],
          })),
        },
        {
          name: 'Tagged With',
          icon: 'i-lucide-tag',
          label: t('SIDEBAR.TAGGED_WITH'),
          collapsible: true,
          showTreeLine: true,
          children: labels.value.map(label => ({
            name: `${label.title}-${label.id}`,
            label: label.title,
            icon: h('span', {
              class: `size-[8px] rounded-sm`,
              style: { backgroundColor: label.color },
            }),
            to: accountScopedRoute(
              'contacts_dashboard_labels_index',
              { label: label.title },
              { page: 1, search: undefined }
            ),
            activeOn: [
              'contacts_dashboard_labels_index',
              'contacts_edit_label',
            ],
          })),
        },
      ],
    },
    {
      name: 'Companies',
      label: t('SIDEBAR.COMPANIES'),
      icon: 'i-lucide-building-2',
      children: [
        {
          name: 'All Companies',
          label: t('SIDEBAR.ALL_COMPANIES'),
          to: accountScopedRoute(
            'companies_dashboard_index',
            {},
            { page: 1, search: undefined }
          ),
          activeOn: ['companies_dashboard_index', 'companies_dashboard_show'],
        },
      ],
    },
    {
      name: 'Reports',
      label: t('SIDEBAR.REPORTS'),
      icon: 'i-lucide-chart-spline',
      children: [
        {
          name: 'Report Overview',
          label: t('SIDEBAR.REPORTS_OVERVIEW'),
          icon: 'i-lucide-activity',
          to: accountScopedRoute('account_overview_reports'),
        },
        {
          name: 'Report Conversation',
          label: t('SIDEBAR.REPORTS_CONVERSATION'),
          icon: 'i-lucide-message-square',
          to: accountScopedRoute('conversation_reports'),
        },
        ...reportRoutes.value,
        {
          name: 'Reports CSAT',
          label: t('SIDEBAR.CSAT'),
          icon: 'i-lucide-smile',
          to: accountScopedRoute('csat_reports'),
        },
        {
          name: 'Reports SLA',
          label: t('SIDEBAR.REPORTS_SLA'),
          icon: 'i-lucide-timer',
          to: accountScopedRoute('sla_reports'),
        },
        {
          name: 'Reports Bot',
          label: t('SIDEBAR.REPORTS_BOT'),
          icon: 'i-lucide-bot',
          to: accountScopedRoute('bot_reports'),
        },
      ],
    },
    {
      name: 'Campaigns',
      label: t('SIDEBAR.CAMPAIGNS'),
      icon: 'i-lucide-megaphone',
      children: [
        {
          name: 'Live chat',
          label: t('SIDEBAR.LIVE_CHAT'),
          to: accountScopedRoute('campaigns_livechat_index'),
        },
        {
          name: 'SMS',
          label: t('SIDEBAR.SMS'),
          to: accountScopedRoute('campaigns_sms_index'),
        },
        {
          name: 'WhatsApp',
          label: t('SIDEBAR.WHATSAPP'),
          to: accountScopedRoute('campaigns_whatsapp_index'),
        },
      ],
    },
    {
      name: 'Portals',
      label: t('SIDEBAR.HELP_CENTER.TITLE'),
      icon: 'i-lucide-library-big',
      activeOn: [
        'portals_new',
        'portals_index',
        'portals_articles_index',
        'portals_articles_new',
        'portals_articles_edit',
        'portals_categories_index',
        'portals_categories_articles_index',
        'portals_categories_articles_edit',
        'portals_locales_index',
        'portals_settings_index',
      ],
      children: hasPortals.value
        ? [
            {
              name: 'Articles',
              label: t('SIDEBAR.HELP_CENTER.ARTICLES'),
              activeOn: [
                'portals_articles_index',
                'portals_articles_new',
                'portals_articles_edit',
              ],
              to: accountScopedRoute('portals_index', {
                navigationPath: 'portals_articles_index',
              }),
            },
            {
              name: 'Categories',
              label: t('SIDEBAR.HELP_CENTER.CATEGORIES'),
              activeOn: [
                'portals_categories_index',
                'portals_categories_articles_index',
                'portals_categories_articles_edit',
              ],
              to: accountScopedRoute('portals_index', {
                navigationPath: 'portals_categories_index',
              }),
            },
            {
              name: 'Locales',
              label: t('SIDEBAR.HELP_CENTER.LOCALES'),
              activeOn: ['portals_locales_index'],
              to: accountScopedRoute('portals_index', {
                navigationPath: 'portals_locales_index',
              }),
            },
            {
              name: 'Settings',
              label: t('SIDEBAR.HELP_CENTER.SETTINGS'),
              activeOn: ['portals_settings_index'],
              to: accountScopedRoute('portals_index', {
                navigationPath: 'portals_settings_index',
              }),
            },
          ]
        : [
            {
              name: 'NewPortal',
              label: t('HELP_CENTER.NEW_PAGE.CREATE_PORTAL_BUTTON'),
              icon: 'i-lucide-plus',
              activeOn: ['portals_new', 'portals_index'],
              to: accountScopedRoute('portals_new'),
            },
          ],
    },
    {
      name: 'Settings',
      label: t('SIDEBAR.SETTINGS'),
      icon: 'i-lucide-bolt',
      children: [
        {
          name: 'Settings Account Settings',
          label: t('SIDEBAR.ACCOUNT_SETTINGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('general_settings_index'),
        },
        {
          name: 'Settings Agents',
          label: t('SIDEBAR.AGENTS'),
          icon: 'i-lucide-square-user',
          to: accountScopedRoute('agent_list'),
        },
        {
          name: 'Settings Teams',
          label: t('SIDEBAR.TEAMS'),
          icon: 'i-lucide-users',
          activeOn: [
            'settings_teams_list',
            'settings_teams_new',
            'settings_teams_finish',
            'settings_teams_add_agents',
            'settings_teams_show',
            'settings_teams_edit',
            'settings_teams_edit_members',
            'settings_teams_edit_finish',
          ],
          to: accountScopedRoute('settings_teams_list'),
        },
        ...(hasAdvancedAssignment.value
          ? [
              {
                name: 'Settings Agent Assignment',
                label: t('SIDEBAR.AGENT_ASSIGNMENT'),
                icon: 'i-lucide-user-cog',
                activeOn: [
                  'assignment_policy_index',
                  'agent_assignment_policy_index',
                  'agent_assignment_policy_create',
                  'agent_assignment_policy_edit',
                  'agent_capacity_policy_index',
                  'agent_capacity_policy_create',
                  'agent_capacity_policy_edit',
                ],
                to: accountScopedRoute('assignment_policy_index'),
              },
            ]
          : []),
        {
          name: 'Settings Inboxes',
          label: t('SIDEBAR.INBOXES'),
          icon: 'i-lucide-inbox',
          activeOn: [
            'settings_inbox_list',
            'settings_inbox_show',
            'settings_inbox_new',
            'settings_inbox_finish',
            'settings_inboxes_page_channel',
            'settings_inboxes_add_agents',
          ],
          to: accountScopedRoute('settings_inbox_list'),
        },
        {
          name: 'Settings Templates',
          label: t('SIDEBAR.WHATSAPP_TEMPLATES'),
          icon: 'i-lucide-layout-template',
          to: accountScopedRoute('settings_templates'),
        },
        {
          name: 'Settings Labels',
          label: t('SIDEBAR.LABELS'),
          icon: 'i-lucide-tags',
          to: accountScopedRoute('labels_list'),
        },
        {
          name: 'Settings Custom Attributes',
          label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
          icon: 'i-lucide-code',
          to: accountScopedRoute('attributes_list'),
        },
        {
          name: 'Settings Automation',
          label: t('SIDEBAR.AUTOMATION'),
          icon: 'i-lucide-repeat',
          to: accountScopedRoute('automation_list'),
        },
        {
          name: 'Settings Agent Bots',
          label: t('SIDEBAR.AGENT_BOTS'),
          icon: 'i-lucide-bot',
          to: accountScopedRoute('agent_bots'),
        },
        {
          name: 'Settings Macros',
          label: t('SIDEBAR.MACROS'),
          icon: 'i-lucide-toy-brick',
          to: accountScopedRoute('macros_wrapper'),
        },
        {
          name: 'Settings Canned Responses',
          label: t('SIDEBAR.CANNED_RESPONSES'),
          icon: 'i-lucide-message-square-quote',
          to: accountScopedRoute('canned_list'),
        },
        {
          name: 'Settings Integrations',
          label: t('SIDEBAR.INTEGRATIONS'),
          icon: 'i-lucide-blocks',
          to: accountScopedRoute('settings_applications'),
        },
        ...(hasDataImport.value
          ? [
              {
                name: 'Settings Data',
                label: t('SIDEBAR.DATA'),
                icon: 'i-lucide-database',
                to: accountScopedRoute('settings_data_imports'),
              },
            ]
          : []),
        {
          name: 'Settings Audit Logs',
          label: t('SIDEBAR.AUDIT_LOGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('auditlogs_list'),
        },
        {
          name: 'Settings Custom Roles',
          label: t('SIDEBAR.CUSTOM_ROLES'),
          icon: 'i-lucide-shield-plus',
          to: accountScopedRoute('custom_roles_list'),
        },
        {
          name: 'Settings Sla',
          label: t('SIDEBAR.SLA'),
          icon: 'i-lucide-clock-alert',
          to: accountScopedRoute('sla_list'),
        },
        {
          name: 'Conversation Workflow',
          label: t('SIDEBAR.CONVERSATION_WORKFLOW'),
          icon: 'i-lucide-workflow',
          to: accountScopedRoute('conversation_workflow_index'),
        },
        {
          name: 'Settings Security',
          label: t('SIDEBAR.SECURITY'),
          icon: 'i-lucide-shield',
          to: accountScopedRoute('security_settings_index'),
        },
        {
          name: 'Settings Billing',
          label: t('SIDEBAR.BILLING'),
          icon: 'i-lucide-credit-card',
          to: accountScopedRoute('billing_settings_index'),
        },
      ],
    },
  ];
});

const expandedItem = ref(null);
const setExpandedItem = name => {
  expandedItem.value = expandedItem.value === name ? null : name;
};

const sidebarWidth = computed(() => 56);

provideSidebarContext({
  expandedItem,
  setExpandedItem,
  isCollapsed: computed(() => false),
  sidebarWidth,
  isResizing: ref(false),
});

// DEFENSIVE ACTIVE MENU ITEM RESOLUTION (CR-05)
const isRouteActive = (routeTarget, activeOnList = []) => {
  if (activeOnList?.includes(route.name)) return true;
  if (!routeTarget) return false;
  if (routeTarget.name && routeTarget.name === route.name) return true;
  try {
    const resolved = router.resolve(routeTarget);
    if (resolved?.name === route.name) return true;
    if (resolved?.path && route.path === resolved.path) return true;
    if (
      resolved?.path &&
      resolved.path !== '/' &&
      route.path.startsWith(`${resolved.path}/`)
    ) {
      return true;
    }
  } catch {
    // ignore route resolve errors
  }
  return false;
};

const isChildAccessible = child => {
  if (child.children?.length) {
    return child.children.some(subChild => isChildAccessible(subChild));
  }
  return child.to ? isAllowed(child.to) : true;
};

const visibleRailMenuItems = computed(() => {
  return menuItems.value.filter(item => {
    if (item.children?.length) {
      return item.children.some(child => isChildAccessible(child));
    }
    return item.to ? isAllowed(item.to) : true;
  });
});

const activeMenuItem = computed(() => {
  return visibleRailMenuItems.value.find(item => {
    if (isRouteActive(item.to, item.activeOn)) return true;
    if (item.children?.length) {
      return item.children.some(child => {
        if (!isChildAccessible(child)) return false;
        if (isRouteActive(child.to, child.activeOn)) return true;
        if (child.children?.length) {
          return child.children.some(
            subChild =>
              isChildAccessible(subChild) &&
              isRouteActive(subChild.to, subChild.activeOn)
          );
        }
        return false;
      });
    }
    return false;
  });
});

const visibleSubmenuItems = computed(() => {
  if (!activeMenuItem.value?.children?.length) return [];
  return activeMenuItem.value.children.filter(child =>
    isChildAccessible(child)
  );
});

const showSubmenuCard = computed(() => {
  return (
    visibleSubmenuItems.value.length > 0 &&
    isSubmenuCardOpen.value &&
    !isMobile.value
  );
});

const handleRailIconClick = item => {
  const accessibleChildren =
    item.children?.filter(child => isChildAccessible(child)) || [];
  if (accessibleChildren.length > 0) {
    isSubmenuCardOpen.value = true;
    const firstChild = accessibleChildren[0]?.to
      ? accessibleChildren[0]
      : accessibleChildren[0]?.children?.find(
          sub => sub.to && isAllowed(sub.to)
        );
    if (firstChild?.to) {
      router.push(firstChild.to);
    }
  } else if (item.to) {
    isSubmenuCardOpen.value = false;
    router.push(item.to);
  }
};

const submenuNavRef = ref(null);
watch(activeMenuItem, (newItem, oldItem) => {
  if (newItem?.name !== oldItem?.name && submenuNavRef.value) {
    submenuNavRef.value.scrollTop = 0;
  }
});
</script>

<template>
  <div
    v-on-click-outside="[
      closeMobileSidebar,
      {
        ignore: [
          '#mobile-sidebar-launcher',
          '[data-popover-content]',
          '[data-popover-backdrop]',
        ],
      },
    ]"
    class="flex h-full overflow-hidden flex-shrink-0 z-40 fixed md:relative top-0 ltr:left-0 rtl:right-0 transition-transform duration-200 ease-out"
    :class="[
      {
        'shadow-lg md:shadow-none': isMobileSidebarOpen,
        'ltr:-translate-x-full rtl:translate-x-full md:ltr:translate-x-0 md:rtl:translate-x-0':
          !isMobileSidebarOpen,
      },
    ]"
  >
    <!-- PRIMARY RAIL (Icon Strip) -->
    <aside
      class="bg-n-background flex flex-col text-sm pb-px h-full w-14 ltr:border-r rtl:border-l border-n-weak flex-shrink-0 pt-2"
    >
      <!-- Navigation Icons -->
      <nav
        class="grid overflow-y-scroll flex-grow gap-2 pb-5 no-scrollbar min-w-0 px-1"
      >
        <ul class="flex flex-col gap-1 m-0 list-none min-w-0 items-center">
          <li v-for="item in visibleRailMenuItems" :key="item.name">
            <button
              type="button"
              class="relative flex items-center justify-center size-10 rounded-lg transition-colors duration-150 ease-out"
              :class="[
                activeMenuItem?.name === item.name
                  ? 'text-n-slate-12 bg-n-alpha-2'
                  : 'text-n-slate-11 hover:bg-n-alpha-2',
              ]"
              :title="item.label"
              @click="handleRailIconClick(item)"
            >
              <Icon v-if="item.icon" :icon="item.icon" class="size-4" />
              <!-- Dot badge unread indicator (W-02) -->
              <span
                v-if="hasUnread(item)"
                class="absolute top-1.5 end-1.5 size-2 rounded-full bg-n-brand ring-2 ring-n-background pointer-events-none"
              />
            </button>
          </li>
        </ul>
      </nav>

      <!-- Profile & Bottom Actions -->
      <section
        class="flex relative flex-col flex-shrink-0 gap-1 justify-between items-center pb-2"
      >
        <SidebarChangelogButton
          v-if="isOnChatwootCloud && !isACustomBrandedInstance"
        />
        <div
          class="px-1 py-1.5 flex-shrink-0 flex w-full z-50 justify-center items-center border-t border-n-weak shadow-[0px_-2px_4px_0px_rgba(27,28,29,0.02)]"
        >
          <SidebarProfileMenu
            is-collapsed
            @open-key-shortcut-modal="emit('openKeyShortcutModal')"
          />
        </div>
      </section>
    </aside>

    <!-- SECONDARY SUBMENU CARD (The "Card" Panel) -->
    <Transition
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 -translate-x-4 max-w-0"
      enter-to-class="opacity-100 translate-x-0 max-w-[240px]"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-x-0 max-w-[240px]"
      leave-to-class="opacity-0 -translate-x-4 max-w-0"
    >
      <div
        v-if="showSubmenuCard"
        class="hidden md:flex flex-col w-56 ltr:border-r rtl:border-l border-n-weak bg-n-background z-30"
      >
        <!-- Card Header -->
        <header
          class="flex items-center justify-between px-4 h-12 border-b border-n-weak"
        >
          <span
            class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider truncate"
          >
            {{ activeMenuItem?.label }}
          </span>
          <button
            type="button"
            class="flex items-center justify-center size-6 rounded-md text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
            :title="t('SIDEBAR.COLLAPSE')"
            @click="isSubmenuCardOpen = false"
          >
            <span class="i-lucide-chevron-left size-4 rtl:rotate-180" />
          </button>
        </header>

        <!-- Card Content (Submenu List) with scroll ref -->
        <nav
          ref="submenuNavRef"
          class="flex-grow overflow-y-auto no-scrollbar p-2"
        >
          <ul class="flex flex-col gap-1 m-0 list-none">
            <SidebarGroup
              v-for="child in visibleSubmenuItems"
              :key="child.name"
              v-bind="child"
            />
          </ul>
        </nav>
      </div>
    </Transition>

    <!-- MOBILE BACKDROP & SUBMENU (Overlay mode for mobile UX) -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition-opacity duration-200 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition-opacity duration-150 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div
          v-if="isMobile && isMobileSidebarOpen"
          class="fixed inset-0 bg-black/40 z-40"
          @click="closeMobileSidebar"
        />
      </Transition>
    </Teleport>

    <Transition
      enter-active-class="transition-transform duration-300 ease-out"
      enter-from-class="translate-x-full"
      enter-to-class="translate-x-0"
      leave-active-class="transition-transform duration-200 ease-in"
      leave-from-class="translate-x-0"
      leave-to-class="translate-x-full"
    >
      <div
        v-if="isMobile && isMobileSidebarOpen && visibleSubmenuItems.length > 0"
        class="fixed inset-y-0 start-14 end-0 z-50 bg-n-background border-s border-n-weak flex flex-col"
      >
        <header
          class="flex items-center justify-between px-4 h-14 border-b border-n-weak flex-shrink-0"
        >
          <span class="text-sm font-semibold text-n-slate-12">
            {{ activeMenuItem?.label }}
          </span>
          <button
            type="button"
            class="p-2 text-n-slate-11 hover:text-n-slate-12"
            @click="closeMobileSidebar"
          >
            <span class="i-lucide-x size-5" />
          </button>
        </header>
        <nav class="flex-1 overflow-y-auto p-4 pb-20">
          <ul class="flex flex-col gap-2 m-0 list-none">
            <SidebarGroup
              v-for="child in visibleSubmenuItems"
              :key="child.name"
              v-bind="child"
              @click="closeMobileSidebar"
            />
          </ul>
        </nav>
      </div>
    </Transition>
  </div>
</template>
