<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import tokopediaClient from 'dashboard/api/channel/tokopediaClient';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';

const { t } = useI18n();

const hasError = ref(false);
const errorMessage = ref('');
const isRequestingAuthorization = ref(false);
const submitted = ref(false);

const inboxName = ref('');
const clientId = ref('');
const clientSecret = ref('');
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
    clientId.value.trim().length > 0 &&
    clientSecret.value.trim().length > 0
  );
});

const requestAuthorization = async () => {
  submitted.value = true;
  if (!isFormValid.value) return;

  isRequestingAuthorization.value = true;
  hasError.value = false;

  try {
    const response = await tokopediaClient.generateAuthorization({
      inbox_name: inboxName.value.trim(),
      client_id: clientId.value.trim(),
      client_secret: clientSecret.value.trim(),
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
      t('INBOX_MGMT.ADD.TOKOPEDIA.ERROR_GENERATE_URL');
  } finally {
    isRequestingAuthorization.value = false;
  }
};
</script>

<template>
  <div class="w-full p-6 pb-16 flex flex-col">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.TOKOPEDIA.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.TOKOPEDIA.DESC')"
    />

    <div
      v-if="hasError"
      class="mb-6 p-4 rounded-xl bg-n-ruby-3 border border-n-ruby-6 text-n-ruby-11 text-sm"
    >
      <div class="font-medium">
        {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.ERROR_TITLE') }}
      </div>
      <p class="mt-1">{{ errorMessage }}</p>
    </div>

    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="requestAuthorization"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !inboxName.trim() }">
          {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.CHANNEL_NAME.LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.TOKOPEDIA.CHANNEL_NAME.PLACEHOLDER')
            "
          />
          <span v-if="submitted && !inboxName.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.CHANNEL_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !clientId.trim() }">
          {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.CLIENT_ID.LABEL') }}
          <input
            v-model="clientId"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.TOKOPEDIA.CLIENT_ID.PLACEHOLDER')"
          />
          <span v-if="submitted && !clientId.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.CLIENT_ID.ERROR') }}
          </span>
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.CLIENT_ID.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: submitted && !clientSecret.trim() }">
          {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.CLIENT_SECRET.LABEL') }}
          <input
            v-model="clientSecret"
            type="password"
            :placeholder="
              $t('INBOX_MGMT.ADD.TOKOPEDIA.CLIENT_SECRET.PLACEHOLDER')
            "
          />
          <span v-if="submitted && !clientSecret.trim()" class="message">
            {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.CLIENT_SECRET.ERROR') }}
          </span>
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.CLIENT_SECRET.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0 mb-4">
        <label>
          {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.ENVIRONMENT.LABEL') }}
        </label>
        <div class="flex gap-4 mt-2">
          <label
            class="inline-flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
          >
            <input
              v-model="environment"
              type="radio"
              value="sandbox"
              name="tokopedia_env"
              class="text-n-brand"
            />
            {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.ENVIRONMENT.SANDBOX') }}
          </label>
          <label
            class="inline-flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
          >
            <input
              v-model="environment"
              type="radio"
              value="production"
              name="tokopedia_env"
              class="text-n-brand"
            />
            {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.ENVIRONMENT.PRODUCTION') }}
          </label>
        </div>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label>
          {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.REDIRECT_URL.LABEL') }}
          <input
            v-model="redirectBaseUrl"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.TOKOPEDIA.REDIRECT_URL.PLACEHOLDER')
            "
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.TOKOPEDIA.REDIRECT_URL.SUBTITLE') }}
        </p>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="isRequestingAuthorization"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.TOKOPEDIA.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
