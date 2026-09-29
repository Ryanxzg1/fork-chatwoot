<script setup>
import { computed, h } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import wootConstants from 'dashboard/constants/globals';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useImpersonation } from 'dashboard/composables/useImpersonation';
import {
  DropdownContainer,
  DropdownBody,
  DropdownItem,
} from 'next/dropdown-menu/base';
import { provideDropdownTeleport } from 'next/dropdown-menu/base/provider';

provideDropdownTeleport();

const { t } = useI18n();
const store = useStore();
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const currentAccountId = useMapGetter('getCurrentAccountId');
const { isImpersonating } = useImpersonation();

const { AVAILABILITY_STATUS_KEYS } = wootConstants;

const statusList = computed(() => [
  t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'),
  t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY'),
  t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE'),
]);

const statusColors = ['bg-n-teal-9', 'bg-n-amber-9', 'bg-n-slate-9'];

const availabilityStatuses = computed(() => {
  return statusList.value.map((statusLabel, index) => ({
    label: statusLabel,
    value: AVAILABILITY_STATUS_KEYS[index],
    color: statusColors[index],
    icon: h('span', { class: [statusColors[index], 'size-2 rounded-full'] }),
    active: currentUserAvailability.value === AVAILABILITY_STATUS_KEYS[index],
  }));
});

const activeStatus = computed(() => {
  return (
    availabilityStatuses.value.find(status => status.active) ||
    availabilityStatuses.value[0]
  );
});

async function changeAvailabilityStatus(availability) {
  if (isImpersonating.value) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.IMPERSONATING_ERROR'));
    return;
  }
  try {
    await store.dispatch('updateAvailability', {
      availability,
      account_id: currentAccountId.value,
    });
  } catch (error) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.SET_AVAILABILITY_ERROR'));
  }
}
</script>

<template>
  <DropdownContainer class="relative shrink-0">
    <template #trigger="{ toggle, isOpen }">
      <button
        type="button"
        class="flex items-center gap-1.5 px-2 h-7 rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-all duration-100 ease-out hover:bg-n-alpha-2 cursor-pointer select-none text-xs"
        :class="{ 'bg-n-alpha-2': isOpen }"
        :title="$t('SIDEBAR.SET_YOUR_AVAILABILITY')"
        @click="toggle"
      >
        <span
          class="size-2 rounded-full shrink-0 duration-1000"
          :class="[
            activeStatus.color,
            { 'animate-pulse': activeStatus.value === 'online' },
          ]"
        />
        <span class="font-medium text-n-slate-12 hidden sm:inline-block">
          {{ activeStatus.label }}
        </span>
        <span
          class="i-lucide-chevron-down size-3 text-n-slate-10 shrink-0 transition-transform duration-150"
          :class="{ 'rotate-180': isOpen }"
        />
      </button>
    </template>
    <DropdownBody class="min-w-32 z-50">
      <DropdownItem
        v-for="status in availabilityStatuses"
        :key="status.value"
        :label="status.label"
        :icon="status.icon"
        class="cursor-pointer"
        @click="changeAvailabilityStatus(status.value)"
      />
    </DropdownBody>
  </DropdownContainer>
</template>
