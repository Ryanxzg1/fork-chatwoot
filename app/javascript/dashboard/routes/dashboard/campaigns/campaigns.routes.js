import { frontendURL } from 'dashboard/helper/URLHelper.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const CampaignsPageRouteView = () =>
  import('./pages/CampaignsPageRouteView.vue');
const LiveChatCampaignsPage = () => import('./pages/LiveChatCampaignsPage.vue');
const SMSCampaignsPage = () => import('./pages/SMSCampaignsPage.vue');
const WhatsAppCampaignsPage = () => import('./pages/WhatsAppCampaignsPage.vue');
const WhatsAppCampaignFormPage = () =>
  import('./pages/WhatsAppCampaignFormPage.vue');
const WhatsAppCampaignAnalyticsPage = () =>
  import('./pages/WhatsAppCampaignAnalyticsPage.vue');

const meta = {
  featureFlag: FEATURE_FLAGS.CAMPAIGNS,
  permissions: ['administrator'],
};

const whatsAppMeta = {
  ...meta,
  featureFlag: FEATURE_FLAGS.WHATSAPP_CAMPAIGNS,
};

const campaignsRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/campaigns'),
      component: CampaignsPageRouteView,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'campaigns_ongoing_index', params: to.params };
          },
        },
        {
          path: 'ongoing',
          name: 'campaigns_ongoing_index',
          meta,
          redirect: to => {
            return { name: 'campaigns_livechat_index', params: to.params };
          },
        },
        {
          path: 'one_off',
          name: 'campaigns_one_off_index',
          meta,
          redirect: to => {
            return { name: 'campaigns_sms_index', params: to.params };
          },
        },
        {
          path: 'live_chat',
          name: 'campaigns_livechat_index',
          meta,
          component: LiveChatCampaignsPage,
        },
        {
          path: 'sms',
          name: 'campaigns_sms_index',
          meta,
          component: SMSCampaignsPage,
        },
        {
          path: 'whatsapp',
          name: 'campaigns_whatsapp_index',
          meta: whatsAppMeta,
          component: WhatsAppCampaignsPage,
        },
        {
          path: 'whatsapp/new',
          name: 'campaigns_whatsapp_new',
          meta: whatsAppMeta,
          component: WhatsAppCampaignFormPage,
        },
        {
          path: 'whatsapp/:campaignId/analytics',
          name: 'campaigns_whatsapp_analytics',
          meta: whatsAppMeta,
          component: WhatsAppCampaignAnalyticsPage,
        },
        {
          path: 'whatsapp/:campaignId',
          name: 'campaigns_whatsapp_edit',
          meta: whatsAppMeta,
          component: WhatsAppCampaignFormPage,
        },
      ],
    },
  ],
};

export default campaignsRoutes;
