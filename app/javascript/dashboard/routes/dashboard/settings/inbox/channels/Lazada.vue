<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import lazadaClient from 'dashboard/api/channel/lazadaClient';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';

const { t } = useI18n();

const hasError = ref(false);
const errorMessage = ref('');
const isRequestingAuthorization = ref(false);
const submitted = ref(false);

const inboxName = ref('');
const appKey = ref('');
const appSecret = ref('');
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
    appKey.value.trim().length > 0 &&
    appSecret.value.trim().length > 0
  );
});

const requestAuthorization = async () => {
  submitted.value = true;
  if (!isFormValid.value) return;

  isRequestingAuthorization.value = true;
  hasError.value = false;

  try {
    const response = await lazadaClient.generateAuthorization({
      inbox_name: inboxName.value.trim(),
      app_key: appKey.value.trim(),
      app_secret: appSecret.value.trim(),
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
      t('INBOX_MGMT.ADD.LAZADA.ERROR_GENERATE_URL');
  } finally {
    isRequestingAuthorization.value = false;
  }
};
</script>

<template>
  <div class="w-full p-6 pb-16 flex flex-col">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.LAZADA.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.LAZADA.DESC')"
    />

    <div
      v-if="hasError"
      class="mb-6 p-4 rounded-xl bg-n-ruby-3 border border-n-ruby-6 text-n-ruby-11 text-sm"
    >
      <div class="font-medium">
        {{ $t('INBOX_MGMT.ADD.LAZADA.ERROR_TITLE') }}
      </div>
      <p class="mt-1">{{ errorMessage }}</p>
    </div>

    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="requestAuthorization"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !inboxName.trim() }">
          {{ $t('INBOX_MGMT.ADD.LAZADA.CHANNEL_NAME.LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.LAZADA.CHANNEL_NAME.PLACEHOLDER')"
          />
          <span v-if="submitted && !inboxName.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.LAZADA.CHANNEL_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !appKey.trim() }">
          {{ $t('INBOX_MGMT.ADD.LAZADA.APP_KEY.LABEL') }}
          <input
            v-model="appKey"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.LAZADA.APP_KEY.PLACEHOLDER')"
          />
          <span v-if="submitted && !appKey.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.LAZADA.APP_KEY.ERROR') }}
          </span>
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.LAZADA.APP_KEY.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !appSecret.trim() }">
          {{ $t('INBOX_MGMT.ADD.LAZADA.APP_SECRET.LABEL') }}
          <input
            v-model="appSecret"
            type="password"
            :placeholder="$t('INBOX_MGMT.ADD.LAZADA.APP_SECRET.PLACEHOLDER')"
          />
          <span v-if="submitted && !appSecret.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.LAZADA.APP_SECRET.ERROR') }}
          </span>
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.LAZADA.APP_SECRET.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0 mb-4">
        <label>
          {{ $t('INBOX_MGMT.ADD.LAZADA.ENVIRONMENT.LABEL') }}
        </label>
        <div class="flex gap-4 mt-2">
          <label
            class="inline-flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
          >
            <input
              v-model="environment"
              type="radio"
              value="sandbox"
              name="lazada_env"
              class="text-n-brand"
            />
            {{ $t('INBOX_MGMT.ADD.LAZADA.ENVIRONMENT.SANDBOX') }}
          </label>
          <label
            class="inline-flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
          >
            <input
              v-model="environment"
              type="radio"
              value="production"
              name="lazada_env"
              class="text-n-brand"
            />
            {{ $t('INBOX_MGMT.ADD.LAZADA.ENVIRONMENT.PRODUCTION') }}
          </label>
        </div>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label>
          {{ $t('INBOX_MGMT.ADD.LAZADA.REDIRECT_URL.LABEL') }}
          <input
            v-model="redirectBaseUrl"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.LAZADA.REDIRECT_URL.PLACEHOLDER')"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.LAZADA.REDIRECT_URL.SUBTITLE') }}
        </p>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="isRequestingAuthorization"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.LAZADA.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
