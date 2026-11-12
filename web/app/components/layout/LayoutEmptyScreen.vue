<script setup lang="ts">
import type { PaveIconName } from '~/utils/paveIcons';

// A screen from the menu that has nothing in it yet (iOS MainEmptyScreen): its title at the top and an honest empty
// state in the middle, instead of made-up content.
const props = defineProps<{
  title: string;
  icon: PaveIconName;
  emptyTitle: string;
  message: string;
}>();

useHead({ title: `${props.title} - PAVE` });
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col overflow-y-auto bg-surface">
    <header class="flex shrink-0 items-center gap-2 px-4 pt-7.5 sm:px-13.25">
      <LayoutMenuLogo />
      <AylaSlashIcon class="h-7.5 w-4.5" />
      <h1 class="text-3xl font-semibold text-brand">{{ title }}</h1>
    </header>
    <div class="flex flex-1 items-center justify-center px-8 py-10">
      <LayoutEmptyState :icon="icon" :title="emptyTitle" :message="message" />
    </div>
  </div>
</template>
