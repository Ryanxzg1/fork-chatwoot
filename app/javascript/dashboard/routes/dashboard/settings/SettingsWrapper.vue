<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineProps({
  keepAlive: {
    type: Boolean,
    default: true,
  },
});

const route = useRoute();

// Routes that manage filters/pagination via query params opt out of
// query-keyed remounts, else every filter change rebuilds the page.
const routeKey = computed(() =>
  route.meta.reuseOnQueryChange ? route.path : route.fullPath
);
</script>

<template>
  <div
    class="flex flex-col w-full h-full m-0 pb-8 pt-4 px-6 overflow-auto bg-n-surface-1"
  >
    <div class="flex items-start w-full max-w-5xl mx-auto">
      <router-view v-slot="{ Component }">
        <Suspense>
          <template #default>
            <keep-alive v-if="keepAlive">
              <component :is="Component" :key="routeKey" />
            </keep-alive>
            <component :is="Component" v-else :key="routeKey" />
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
  </div>
</template>
