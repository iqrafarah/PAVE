<script setup lang="ts">
import type { PaveIconName } from '~/utils/paveIcons';

// iOS PaveEmptyState: a green icon on a soft green tile, a title and a short message, centered.
defineProps<{
  icon: PaveIconName;
  title: string;
  message: string;
}>();
</script>

<template>
  <div class="mx-auto flex max-w-78.25 flex-col items-center text-center">
    <span class="flex size-18 items-center justify-center rounded-empty-icon bg-tint text-brand" aria-hidden="true">
      <LayoutPaveIcon :name="icon" class="size-7.5" />
    </span>
    <h2 class="mt-5.5 font-heading text-xl font-semibold text-heading">{{ title }}</h2>
    <p class="mt-2 text-sm font-medium text-subtle">{{ message }}</p>
    <slot />
  </div>
</template>
