<script setup lang="ts">
// The top of a settings page (Figma 1393:5669): the menu on small screens, Ayla's slash and the name of the page. A
// page inside the settings gets a way back to them above its name.
defineProps<{
  title: string;
  backTo?: string;
  backLabel?: string;
}>();
</script>

<template>
  <header class="flex flex-col gap-1 px-4 pt-7.5 sm:px-13.25">
    <div class="flex items-center gap-2">
      <LayoutMenuLogo />
      <AylaSlashIcon class="h-7.5 w-4.5" />
      <h1 class="text-3xl font-semibold text-brand">{{ title }}</h1>
    </div>
    <NuxtLink
      v-if="backTo"
      :to="backTo"
      class="-ml-2 flex min-h-9 items-center gap-2 self-start rounded-lg px-2 text-sm font-medium text-subtle hover:bg-tint hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
    >
      <LayoutPaveIcon name="chevronRight" class="h-3 w-1.75 rotate-180" />
      {{ backLabel }}
    </NuxtLink>
  </header>
</template>
