<script setup>
defineProps({
  searchKey: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div v-show="false">
    <span>{{ searchKey }}</span>
  </div>
</template>
