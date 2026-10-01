import { mount } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import ChannelItem from '../ChannelItem.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountId: { value: 15 },
    isOnChatwootCloud: { value: false },
  }),
}));

describe('ChannelItem.vue', () => {
  const originalChatwootConfig = window.chatwootConfig;

  beforeEach(() => {
    window.chatwootConfig = {};
  });

  afterEach(() => {
    window.chatwootConfig = originalChatwootConfig;
  });

  const mountComponent = (channel, enabledFeatures = {}) =>
    mount(ChannelItem, {
      props: {
        channel,
        enabledFeatures,
      },
      global: {
        stubs: {
          ChannelSelector: {
            template: `
              <button
                :disabled="disabled"
                data-testid="channel-button"
                @click="$emit('click')"
              >
                <span>{{ title }}</span>
                <span v-if="requiresSetup" data-testid="requires-setup-badge">{{ setupBadgeText }}</span>
                <span v-if="setupNotice" data-testid="setup-notice">{{ setupNotice }}</span>
              </button>
            `,
            props: [
              'title',
              'description',
              'icon',
              'isComingSoon',
              'isBeta',
              'hasVoiceBadge',
              'requiresSetup',
              'setupBadgeText',
              'setupNotice',
              'disabled',
            ],
            emits: ['click'],
          },
          ChannelSetupGuideDialog: {
            template: '<div data-testid="guide-dialog" />',
            methods: { open: vi.fn(), close: vi.fn() },
          },
        },
      },
    });

  it('enables self-contained channels (website, shopee, email, whatsapp, api) by default even if enabledFeatures is empty', () => {
    const shopeeChannel = {
      key: 'shopee',
      title: 'Shopee',
      description: 'Shopee store',
      icon: 'i-lucide-shopping-bag',
    };
    const wrapper = mountComponent(shopeeChannel, {});

    const button = wrapper.find('[data-testid="channel-button"]');
    expect(button.attributes('disabled')).toBeUndefined();
    expect(wrapper.find('[data-testid="requires-setup-badge"]').exists()).toBe(
      false
    );
  });

  it('marks Facebook as requiring Super Admin setup when fbAppId is not configured', async () => {
    window.chatwootConfig = { fbAppId: '' };
    const fbChannel = {
      key: 'facebook',
      title: 'Facebook',
      description: 'Facebook page',
      icon: 'i-woot-messenger',
    };
    const wrapper = mountComponent(fbChannel, { channel_facebook: true });

    expect(wrapper.find('[data-testid="requires-setup-badge"]').exists()).toBe(
      true
    );
    expect(wrapper.find('[data-testid="setup-notice"]').text()).toContain(
      'INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FACEBOOK.SHORT_NOTICE'
    );
    // Button should NOT be disabled so user can click to see instructions
    const button = wrapper.find('[data-testid="channel-button"]');
    expect(button.attributes('disabled')).toBeUndefined();
  });

  it('emits channelItemClick for active channel when clicked', async () => {
    const telegramChannel = {
      key: 'telegram',
      title: 'Telegram',
      description: 'Telegram bot',
      icon: 'i-woot-telegram',
    };
    const wrapper = mountComponent(telegramChannel, {});

    await wrapper.find('[data-testid="channel-button"]').trigger('click');
    expect(wrapper.emitted('channelItemClick')).toEqual([['telegram']]);
  });
});
