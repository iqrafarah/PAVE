<script setup lang="ts">
// Placeholder cards while Ayla fetches data (Figma "Kluis doorzoeken"). Purely visual, so hidden from screen readers.
const CARD_COUNT = 6;
const TOOLBAR_TABS = 5;
</script>

<template>
  <div aria-hidden="true">
    <div class="flex items-center gap-4">
      <span class="h-4.25 w-8.5 rounded-xs bg-bubble" />
      <span v-for="tab in TOOLBAR_TABS" :key="tab" class="hidden h-4.25 w-18.75 rounded-xs bg-bubble sm:block" />
      <span class="ml-auto size-10 rounded-lg bg-bubble" />
      <span class="size-10 rounded-lg bg-bubble" />
      <span class="h-10 w-32.5 rounded-lg bg-bubble" />
    </div>
    <div class="mt-15 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
      <div v-for="card in CARD_COUNT" :key="card" class="relative h-80 rounded-xl bg-bubble">
        <span class="absolute left-4.5 top-3.5 h-18.75 w-1/3 rounded-md bg-skeleton-image" />
        <span class="absolute left-5.5 top-28.5 h-7.25 w-2/3 rounded-lg bg-skeleton" />
        <span class="absolute left-5.5 top-38 h-7.25 w-1/3 rounded-lg bg-skeleton" />
        <span class="absolute left-5.5 top-48.25 h-7.25 w-2/3 rounded-lg bg-skeleton" />
        <span class="absolute left-5.5 top-66 h-7.25 w-5/6 rounded-lg bg-skeleton" />
      </div>
    </div>
  </div>
</template>
