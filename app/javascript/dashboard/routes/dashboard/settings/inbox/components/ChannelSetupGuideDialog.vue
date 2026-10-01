<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  channel: {
    type: Object,
    default: () => ({}),
  },
  requirement: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const dialogRef = ref(null);

const dialogTitle = computed(() => {
  return t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.DIALOG_TITLE', {
    channel: props.channel?.title || 'Channel',
  });
});

const dialogSubtitle = computed(() => {
  return t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.DIALOG_SUBTITLE');
});

const confirmButtonLabel = computed(() => {
  if (props.requirement?.type === 'account_feature') {
    return t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.OPEN_ACCOUNT_FEATURES');
  }
  return t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.OPEN_SUPER_ADMIN');
});

const onConfirm = () => {
  const targetUrl =
    props.requirement?.targetUrl || '/super_admin/installation_configs';
  window.open(targetUrl, '_blank', 'noopener,noreferrer');
  dialogRef.value?.close();
};

const open = () => {
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="dialogTitle"
    :description="dialogSubtitle"
    :confirm-button-label="confirmButtonLabel"
    :cancel-button-label="t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.CLOSE')"
    width="lg"
    @confirm="onConfirm"
  >
    <div class="flex flex-col gap-4 py-2">
      <!-- Channel Info Card -->
      <div
        class="flex items-center justify-between p-3.5 rounded-xl bg-n-alpha-1 border border-n-weak"
      >
        <div class="flex items-center gap-3">
          <div
            class="flex size-10 items-center justify-center rounded-full bg-n-alpha-2"
          >
            <Icon
              v-if="channel?.icon"
              :icon="channel.icon"
              class="text-n-slate-10 size-5"
            />
          </div>
          <div class="flex flex-col">
            <span class="text-sm font-semibold text-n-slate-12 capitalize">
              {{ channel?.title }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ channel?.description }}
            </span>
          </div>
        </div>

        <Label
          :label="t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.BADGE')"
          color="amber"
          compact
        />
      </div>

      <!-- Step-by-step instructions -->
      <div class="flex flex-col gap-2 mt-1">
        <h4
          class="text-xs font-semibold uppercase tracking-wider text-n-slate-11"
        >
          {{ t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.STEPS_TITLE') }}
        </h4>

        <ol
          v-if="requirement?.steps?.length"
          class="space-y-2 text-sm text-n-slate-12"
        >
          <li
            v-for="(step, index) in requirement.steps"
            :key="index"
            class="flex items-start gap-2.5 rounded-lg bg-n-solid-2/60 p-2.5 border border-n-weak"
          >
            <span
              class="flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-n-alpha-2 text-xs font-bold text-n-slate-11"
            >
              {{ index + 1 }}
            </span>
            <span class="text-xs leading-relaxed text-n-slate-12 font-medium">
              {{ step }}
            </span>
          </li>
        </ol>
      </div>

      <!-- Admin Pro Tip -->
      <div
        class="flex items-start gap-2.5 rounded-xl bg-n-blue-3 border border-n-blue-4 p-3 text-start"
      >
        <Icon
          icon="i-lucide-info"
          class="text-n-blue-11 size-4 mt-0.5 flex-shrink-0"
        />
        <p class="text-xs text-n-blue-11 leading-relaxed m-0">
          {{ t('INBOX_MGMT.ADD.AUTH.SUPER_ADMIN_SETUP.PRO_TIP') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>
