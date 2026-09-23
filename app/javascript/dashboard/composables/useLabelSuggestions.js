import { computed, onMounted } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

export function useLabelSuggestions() {
  const store = useStore();
  const { isCloudFeatureEnabled } = useAccount();
  const appIntegrations = useMapGetter('integrations/getAppIntegrations');

  const captainTasksEnabled = computed(() => {
    return isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_TASKS);
  });

  const aiIntegration = computed(
    () =>
      appIntegrations.value.find(
        integration => integration.id === 'openai' && !!integration.hooks.length
      )?.hooks[0]
  );

  const isLabelSuggestionFeatureEnabled = computed(() => {
    if (aiIntegration.value) {
      const { settings = {} } = aiIntegration.value || {};
      return !!settings.label_suggestion;
    }
    return false;
  });

  const fetchIntegrationsIfRequired = async () => {
    if (!appIntegrations.value.length) {
      await store.dispatch('integrations/get');
    }
  };

  /**
   * Gets label suggestions for the current conversation.
   * @returns {Promise<string[]>} An array of suggested labels.
   */
  const getLabelSuggestions = async () => {
    return [];
  };

  onMounted(() => {
    fetchIntegrationsIfRequired();
  });

  return {
    captainTasksEnabled,
    isLabelSuggestionFeatureEnabled,
    getLabelSuggestions,
  };
}
