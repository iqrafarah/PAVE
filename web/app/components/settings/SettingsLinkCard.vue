<script setup lang="ts">
// A row in the settings that opens a page of its own (iOS SettingsScreen: "Wat Ayla over je weet", "Ingelogde
// apparaten"): a title, a line under it and an arrow.
defineProps<{
  to: string;
  title: string;
  message: string;
}>();
</script>

<template>
  <NuxtLink
    :to="to"
    class="flex items-center gap-3 rounded-pill bg-white p-3 hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
  >
    <span class="flex min-w-0 flex-1 flex-col gap-1">
      <span class="text-base font-semibold text-heading">{{ title }}</span>
      <span class="text-xs/normal text-subtle">{{ message }}</span>
    </span>
    <LayoutPaveIcon name="chevronRight" class="h-4 w-2.25 text-subtle" />
  </NuxtLink>
</template>
