<script setup lang="ts">
defineProps<{
  isChecked: boolean;
}>();
</script>

<template>
  <svg
    v-if="isChecked"
    class="size-4 shrink-0 text-brand"
    fill="none"
    viewBox="0 0 24 24"
    stroke-width="2"
    stroke="currentColor"
    aria-hidden="true"
  >
    <path
      stroke-linecap="round"
      stroke-linejoin="round"
      d="m4.5 12.75 6 6 9-13.5"
    />
  </svg>
  <svg
    v-else
    class="size-4 shrink-0 text-muted"
    fill="none"
    viewBox="0 0 24 24"
    stroke-width="1.5"
    stroke="currentColor"
    aria-hidden="true"
  >
    <circle cx="12" cy="12" r="8" />
  </svg>
</template>
