<script setup>
import { onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineProps({
  keepAlive: { type: Boolean, default: true },
});

const store = useStore();

onMounted(() => {
  store.dispatch('campaigns/get');
  store.dispatch('labels/get');
});
</script>

<template>
  <div
    class="flex flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-surface-1"
  >
    <router-view v-slot="{ Component }">
      <Suspense>
        <template #default>
          <keep-alive v-if="keepAlive">
            <component :is="Component" />
          </keep-alive>
          <component :is="Component" v-else />
        </template>
        <template #fallback>
          <div
            class="flex items-center justify-center w-full h-full min-h-[300px]"
          >
            <Spinner :size="32" class="text-n-brand" />
          </div>
        </template>
      </Suspense>
    </router-view>
  </div>
</template>
