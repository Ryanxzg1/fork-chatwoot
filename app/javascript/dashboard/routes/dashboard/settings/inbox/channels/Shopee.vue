<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import shopeeClient from 'dashboard/api/channel/shopeeClient';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';

const { t } = useI18n();

const hasError = ref(false);
const errorMessage = ref('');
const isRequestingAuthorization = ref(false);
const submitted = ref(false);

const inboxName = ref('');
const partnerId = ref('');
const partnerKey = ref('');
const environment = ref('sandbox');
const redirectBaseUrl = ref(window.location.origin);

onMounted(() => {
  const urlParams = new URLSearchParams(window.location.search);
  const err = urlParams.get('error');

  if (err) {
    hasError.value = true;
    errorMessage.value = err;
    const cleanURL = window.location.pathname;
    window.history.replaceState({}, document.title, cleanURL);
  }
});

const isFormValid = computed(() => {
  return (
    inboxName.value.trim().length > 0 &&
    partnerId.value.trim().length > 0 &&
    partnerKey.value.trim().length > 0
  );
});

const requestAuthorization = async () => {
  submitted.value = true;
  if (!isFormValid.value) return;

  isRequestingAuthorization.value = true;
  hasError.value = false;

  try {
    const response = await shopeeClient.generateAuthorization({
      inbox_name: inboxName.value.trim(),
      partner_id: partnerId.value.trim(),
      partner_key: partnerKey.value.trim(),
      environment: environment.value,
      redirect_url: redirectBaseUrl.value.trim(),
    });

    const {
      data: { url },
    } = response;

    if (url) {
      window.location.href = url;
    }
  } catch (err) {
    hasError.value = true;
    errorMessage.value =
      err.response?.data?.error ||
      t('INBOX_MGMT.ADD.SHOPEE.ERROR_GENERATE_URL');
  } finally {
    isRequestingAuthorization.value = false;
  }
};
</script>

<template>
  <div class="w-full p-6 pb-16 flex flex-col">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.SHOPEE.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.SHOPEE.DESC')"
    />

    <div
      v-if="hasError"
      class="mb-6 p-4 rounded-xl bg-n-ruby-3 border border-n-ruby-6 text-n-ruby-11 text-sm"
    >
      <div class="font-medium">
        {{ $t('INBOX_MGMT.ADD.SHOPEE.ERROR_TITLE') }}
      </div>
      <p class="mt-1">{{ errorMessage }}</p>
    </div>

    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="requestAuthorization"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !inboxName.trim() }">
          {{ $t('INBOX_MGMT.ADD.SHOPEE.CHANNEL_NAME.LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.SHOPEE.CHANNEL_NAME.PLACEHOLDER')"
          />
          <span v-if="submitted && !inboxName.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.SHOPEE.CHANNEL_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !partnerId.trim() }">
          {{ $t('INBOX_MGMT.ADD.SHOPEE.PARTNER_ID.LABEL') }}
          <input
            v-model="partnerId"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.SHOPEE.PARTNER_ID.PLACEHOLDER')"
          />
          <span v-if="submitted && !partnerId.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.SHOPEE.PARTNER_ID.ERROR') }}
          </span>
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.SHOPEE.PARTNER_ID.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !partnerKey.trim() }">
          {{ $t('INBOX_MGMT.ADD.SHOPEE.PARTNER_KEY.LABEL') }}
          <input
            v-model="partnerKey"
            type="password"
            :placeholder="$t('INBOX_MGMT.ADD.SHOPEE.PARTNER_KEY.PLACEHOLDER')"
          />
          <span v-if="submitted && !partnerKey.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.SHOPEE.PARTNER_KEY.ERROR') }}
          </span>
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.SHOPEE.PARTNER_KEY.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0 mb-4">
        <label>
          {{ $t('INBOX_MGMT.ADD.SHOPEE.ENVIRONMENT.LABEL') }}
        </label>
        <div class="flex gap-4 mt-2">
          <label
            class="inline-flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
          >
            <input
              v-model="environment"
              type="radio"
              value="sandbox"
              name="shopee_env"
              class="text-n-brand"
            />
            {{ $t('INBOX_MGMT.ADD.SHOPEE.ENVIRONMENT.SANDBOX') }}
          </label>
          <label
            class="inline-flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
          >
            <input
              v-model="environment"
              type="radio"
              value="production"
              name="shopee_env"
              class="text-n-brand"
            />
            {{ $t('INBOX_MGMT.ADD.SHOPEE.ENVIRONMENT.PRODUCTION') }}
          </label>
        </div>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label>
          {{ $t('INBOX_MGMT.ADD.SHOPEE.REDIRECT_URL.LABEL') }}
          <input
            v-model="redirectBaseUrl"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.SHOPEE.REDIRECT_URL.PLACEHOLDER')"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.SHOPEE.REDIRECT_URL.SUBTITLE') }}
        </p>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="isRequestingAuthorization"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.SHOPEE.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
