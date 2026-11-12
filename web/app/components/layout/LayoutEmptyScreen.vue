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
    <!-- The menu on the left and the title in the middle, as on the settings pages. -->
    <header class="grid shrink-0 grid-cols-[1fr_auto_1fr] items-center gap-2 px-4 pt-7.5 sm:px-13.25">
      <div class="justify-self-start"><LayoutMenuLogo /></div>
      <div class="flex items-center justify-center gap-2">
        <AylaSlashIcon class="h-7.5 w-4.5" />
        <h1 class="text-3xl font-semibold text-brand max-sm:text-2xl">{{ title }}</h1>
      </div>
      <span aria-hidden="true" />
    </header>
    <div class="flex flex-1 items-center justify-center px-8 py-10">
      <LayoutEmptyState :icon="icon" :title="emptyTitle" :message="message" />
    </div>
  </div>
</template>
