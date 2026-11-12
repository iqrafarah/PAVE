<script setup lang="ts">
import type { MemoryCategory } from '~/types/ayla';

// A folder in "Wat Ayla over je weet" (iOS AylaMemoryFolder): the category with its icon and how much Ayla remembers.
const props = defineProps<{
  category: MemoryCategory;
  title: string;
  count: number;
}>();

const style = computed(() => MEMORY_CATEGORY_STYLES[props.category]);
const countLabel = computed(() => getFolderCount(props.count));
</script>

<template>
  <NuxtLink
    :to="{ query: { map: category } }"
    :aria-label="`${title}, ${countLabel.toLowerCase()}`"
    :class="{ 'opacity-75': count === 0 }"
    class="flex min-h-32 flex-col items-start rounded-2xl border border-card-border bg-white p-3.5 hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
  >
    <span :class="style.tintClass" class="flex size-10 items-center justify-center rounded-xl text-brand" aria-hidden="true">
      <LayoutPaveIcon :name="style.icon" class="size-5" />
    </span>
    <span class="mt-auto line-clamp-2 pt-3.5 text-folder font-medium text-heading">{{ title }}</span>
    <span class="mt-0.5 text-sm font-medium text-ink-soft">{{ countLabel }}</span>
  </NuxtLink>
</template>
