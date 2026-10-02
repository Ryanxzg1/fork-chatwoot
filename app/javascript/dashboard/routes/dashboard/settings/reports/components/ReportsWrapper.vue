<script setup>
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
</script>

<template>
  <div class="overflow-auto bg-n-surface-1 w-full">
    <div class="w-full max-w-[96rem] mx-auto px-6 py-6">
      <router-view v-slot="{ Component }">
        <Suspense>
          <template #default>
            <component :is="Component" />
          </template>
          <template #fallback>
            <div
              class="flex items-center justify-center p-12 w-full min-h-[300px]"
            >
              <Spinner :size="32" class="text-n-brand" />
            </div>
          </template>
        </Suspense>
      </router-view>
    </div>
  </div>
</template>
