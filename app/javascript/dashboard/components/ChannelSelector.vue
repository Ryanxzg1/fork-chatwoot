<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    required: true,
  },
  isComingSoon: {
    type: Boolean,
    default: false,
  },
  isBeta: {
    type: Boolean,
    default: false,
  },
  hasVoiceBadge: {
    type: Boolean,
    default: false,
  },
  requiresSetup: {
    type: Boolean,
    default: false,
  },
  setupBadgeText: {
    type: String,
    default: '',
  },
  setupNotice: {
    type: String,
    default: '',
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
</script>

<template>
  <button
    type="button"
    :disabled="disabled && !requiresSetup"
    class="relative bg-n-solid-1 gap-4 cursor-pointer rounded-2xl flex flex-col justify-between transition-all duration-200 ease-in -m-px py-6 px-5 items-start border border-solid border-n-weak w-full text-start focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand focus-visible:ring-offset-2"
    :class="{
      'hover:border-n-blue-9 hover:shadow-md':
        !disabled && !isComingSoon && !requiresSetup,
      'hover:border-n-amber-9 hover:shadow-sm': requiresSetup && !isComingSoon,
      'disabled:opacity-60 disabled:cursor-not-allowed':
        disabled && !isComingSoon && !requiresSetup,
      'cursor-not-allowed disabled:opacity-80': isComingSoon,
    }"
  >
    <div class="flex flex-col items-start gap-4 w-full">
      <div class="flex items-center justify-between w-full">
        <div class="relative">
          <div
            class="flex size-10 items-center justify-center rounded-full bg-n-alpha-2"
          >
            <Icon :icon="icon" class="text-n-slate-10 size-6" />
          </div>
          <div
            v-if="hasVoiceBadge"
            class="absolute -top-1 ltr:-right-1 rtl:-left-1 flex size-4 items-center justify-center rounded-full bg-n-alpha-2 ring-2 ring-n-solid-1"
          >
            <Icon
              icon="i-lucide-audio-lines"
              class="text-n-slate-10 size-2.5"
            />
          </div>
        </div>

        <Label
          v-if="requiresSetup && !isComingSoon"
          v-tooltip.top="t('CHANNEL_SELECTOR.CLICK_TO_CONFIGURE')"
          :label="setupBadgeText || t('CHANNEL_SELECTOR.REQUIRES_SETUP')"
          color="amber"
          compact
        />
      </div>

      <div class="flex flex-col items-start gap-1.5 w-full">
        <div class="flex items-center gap-2 flex-wrap">
          <h3 class="text-n-slate-12 text-sm text-start font-medium capitalize">
            {{ title }}
          </h3>
          <Label
            v-if="isBeta && !isComingSoon"
            v-tooltip.top="t('GENERAL.BETA_DESCRIPTION')"
            :label="t('GENERAL.BETA')"
            color="blue"
            compact
          />
        </div>
        <p class="text-n-slate-11 text-start text-sm">
          {{ description }}
        </p>
      </div>
    </div>

    <div
      v-if="requiresSetup && setupNotice && !isComingSoon"
      class="mt-2 w-full rounded-xl bg-n-amber-2 border border-n-amber-4 px-3 py-2 flex items-start gap-2 text-start"
    >
      <Icon
        icon="i-lucide-settings-2"
        class="text-n-amber-11 size-4 mt-0.5 flex-shrink-0"
      />
      <span class="text-xs text-n-amber-11 font-normal leading-relaxed">
        {{ setupNotice }}
      </span>
    </div>

    <div
      v-if="isComingSoon"
      class="absolute inset-0 flex items-center justify-center backdrop-blur-[2px] rounded-2xl bg-gradient-to-br from-n-surface-1/90 via-n-surface-1/70 to-n-surface-1/95 cursor-not-allowed"
    >
      <span class="text-n-slate-12 font-medium text-sm">
        {{ t('CHANNEL_SELECTOR.COMING_SOON') }} 🚀
      </span>
    </div>
  </button>
</template>
