import { computed } from 'vue';

export function useCaptain() {
  const captainEnabled = computed(() => false);
  const captainTasksEnabled = computed(() => false);
  const captainLimits = computed(() => null);
  const documentLimits = computed(() => null);
  const responseLimits = computed(() => null);
  const isFetchingLimits = computed(() => false);

  const fetchLimits = () => {};
  const rewriteContent = async () => ({ message: '' });
  const summarizeConversation = async () => ({ message: '' });
  const getReplySuggestion = async () => ({ message: '' });
  const followUp = async () => ({ message: '' });
  const processEvent = async () => ({ message: '' });

  return {
    captainEnabled,
    captainTasksEnabled,
    captainLimits,
    documentLimits,
    responseLimits,
    fetchLimits,
    isFetchingLimits,
    draftMessage: computed(() => ''),
    currentChat: computed(() => null),
    rewriteContent,
    summarizeConversation,
    getReplySuggestion,
    followUp,
    processEvent,
  };
}
