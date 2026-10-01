<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import ChannelSelector from 'dashboard/components/ChannelSelector.vue';
import ChannelSetupGuideDialog from 'dashboard/routes/dashboard/settings/inbox/components/ChannelSetupGuideDialog.vue';

const props = defineProps({
  channel: {
    type: Object,
    required: true,
  },
  enabledFeatures: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['channelItemClick']);
const { t } = useI18n();
const { accountId, isOnChatwootCloud } = useAccount();
const guideDialogRef = ref(null);

const hasFbConfigured = computed(() => {
  return Boolean(window.chatwootConfig?.fbAppId);
});

const hasInstagramConfigured = computed(() => {
  return Boolean(window.chatwootConfig?.instagramAppId);
});

const hasTiktokConfigured = computed(() => {
  return Boolean(window.chatwootConfig?.tiktokAppId);
});

const isAccountFeatureDisabled = computed(() => {
  const { key } = props.channel;
  const featureMap = {
    website: 'channel_website',
    facebook: 'channel_facebook',
    email: 'channel_email',
    instagram: 'channel_instagram',
    tiktok: 'channel_tiktok',
    shopee: 'channel_shopee',
    voice: 'channel_voice',
    whatsapp_call: 'channel_voice',
  };
  const featureKey = featureMap[key];
  if (!featureKey) return false;

  return (
    Object.keys(props.enabledFeatures).length > 0 &&
    props.enabledFeatures[featureKey] === false
  );
});

const setupRequirement = computed(() => {
  const { key } = props.channel;

  if (isAccountFeatureDisabled.value) {
    return {
      type: 'account_feature',
      shortNotice: t(
        'INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FEATURE_DISABLED.SHORT_NOTICE'
      ),
      steps: [
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FEATURE_DISABLED.STEP_1'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FEATURE_DISABLED.STEP_2'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FEATURE_DISABLED.STEP_3'),
      ],
      targetUrl: accountId.value
        ? `/super_admin/accounts/${accountId.value}/edit`
        : '/super_admin/accounts',
    };
  }

  if (key === 'facebook' && !hasFbConfigured.value) {
    return {
      type: 'global_config',
      shortNotice: t(
        'INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FACEBOOK.SHORT_NOTICE'
      ),
      steps: [
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FACEBOOK.STEP_1'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FACEBOOK.STEP_2'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.FACEBOOK.STEP_3'),
      ],
      targetUrl: '/super_admin/installation_configs',
    };
  }

  if (key === 'instagram' && !hasInstagramConfigured.value) {
    return {
      type: 'global_config',
      shortNotice: t(
        'INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.INSTAGRAM.SHORT_NOTICE'
      ),
      steps: [
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.INSTAGRAM.STEP_1'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.INSTAGRAM.STEP_2'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.INSTAGRAM.STEP_3'),
      ],
      targetUrl: '/super_admin/installation_configs',
    };
  }

  if (key === 'tiktok' && !hasTiktokConfigured.value) {
    return {
      type: 'global_config',
      shortNotice: t(
        'INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.TIKTOK.SHORT_NOTICE'
      ),
      steps: [
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.TIKTOK.STEP_1'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.TIKTOK.STEP_2'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.TIKTOK.STEP_3'),
      ],
      targetUrl: '/super_admin/installation_configs',
    };
  }

  if (
    ['voice', 'whatsapp_call'].includes(key) &&
    !props.enabledFeatures.channel_voice
  ) {
    return {
      type: 'account_feature',
      shortNotice:
        key === 'voice'
          ? t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.VOICE.SHORT_NOTICE')
          : t(
              'INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.WHATSAPP_CALL.SHORT_NOTICE'
            ),
      steps: [
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.VOICE.STEP_1'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.VOICE.STEP_2'),
        t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.VOICE.STEP_3'),
      ],
      targetUrl: accountId.value
        ? `/super_admin/accounts/${accountId.value}/edit`
        : '/super_admin/accounts',
    };
  }

  return null;
});

const requiresSetup = computed(() => Boolean(setupRequirement.value));

const setupBadgeText = computed(() => {
  return t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.BADGE');
});

const setupNotice = computed(() => {
  return setupRequirement.value?.shortNotice || '';
});

const isActive = computed(() => {
  const { key } = props.channel;

  if (requiresSetup.value) {
    return false;
  }

  if (key === 'website') {
    return props.enabledFeatures.channel_website !== false;
  }
  if (key === 'email') {
    return props.enabledFeatures.channel_email !== false;
  }
  if (key === 'shopee') {
    return props.enabledFeatures.channel_shopee !== false;
  }
  if (key === 'facebook') {
    return (
      hasFbConfigured.value && props.enabledFeatures.channel_facebook !== false
    );
  }
  if (key === 'instagram') {
    return (
      hasInstagramConfigured.value &&
      props.enabledFeatures.channel_instagram !== false
    );
  }
  if (key === 'tiktok') {
    return (
      hasTiktokConfigured.value &&
      props.enabledFeatures.channel_tiktok !== false
    );
  }
  if (key === 'voice' || key === 'whatsapp_call') {
    return Boolean(props.enabledFeatures.channel_voice);
  }

  return true;
});

const isComingSoon = computed(() => {
  return false;
});

const isBeta = computed(() => {
  return ['tiktok', 'voice', 'whatsapp_call'].includes(props.channel.key);
});

const canRequestTiktokAccess = computed(() => {
  return (
    props.channel.key === 'tiktok' &&
    isOnChatwootCloud.value &&
    hasTiktokConfigured.value &&
    Object.keys(props.enabledFeatures).length > 0 &&
    !props.enabledFeatures.channel_tiktok
  );
});

const hasVoiceBadge = computed(() => {
  return (
    ['voice', 'whatsapp_call'].includes(props.channel.key) &&
    Boolean(props.enabledFeatures.channel_voice)
  );
});

const onItemClick = () => {
  if (canRequestTiktokAccess.value) {
    window.$chatwoot?.toggle();
    return;
  }

  if (requiresSetup.value) {
    guideDialogRef.value?.open();
    return;
  }

  if (isActive.value) {
    emit('channelItemClick', props.channel.key);
  }
};
</script>

<template>
  <div class="flex h-full w-full">
    <ChannelSelector
      :title="channel.title"
      :description="channel.description"
      :icon="channel.icon"
      :is-coming-soon="isComingSoon"
      :is-beta="isBeta"
      :has-voice-badge="hasVoiceBadge"
      :requires-setup="requiresSetup"
      :setup-badge-text="setupBadgeText"
      :setup-notice="setupNotice"
      :disabled="!isActive && !canRequestTiktokAccess && !requiresSetup"
      class="h-full"
      @click="onItemClick"
    />
    <ChannelSetupGuideDialog
      v-if="requiresSetup"
      ref="guideDialogRef"
      :channel="channel"
      :requirement="setupRequirement"
    />
  </div>
</template>
