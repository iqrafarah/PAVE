<script setup lang="ts">
// The bar on top of "Wat Ayla over je weet" and its folders, like the iPhone's navigation bar: back on the left,
// the title in the middle, + on the right.
defineProps<{
  title: string;
  backLabel: string;
  backTo: string | { query: Record<string, never> };
  addLabel?: string;
}>();

const emit = defineEmits<{
  add: [];
}>();
</script>

<template>
  <header class="flex min-h-14 items-center gap-2 px-2 pt-2 sm:px-4">
    <div class="flex min-w-0 flex-1 basis-0">
      <NuxtLink
        :to="backTo"
        class="flex min-h-11 min-w-0 items-center gap-1.5 rounded-lg px-2 text-base text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand"
      >
        <LayoutPaveIcon name="chevronRight" class="h-4 w-2.25 rotate-180" />
        <span class="truncate max-sm:sr-only">{{ backLabel }}</span>
      </NuxtLink>
    </div>
    <h1 class="truncate text-base font-semibold text-heading">{{ title }}</h1>
    <div class="flex flex-1 basis-0 justify-end">
      <button
        v-if="addLabel"
        type="button"
        :aria-label="addLabel"
        class="flex size-11 items-center justify-center rounded-full text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
        @click="emit('add')"
      >
        <LayoutPaveIcon name="plus" class="size-4.25" />
      </button>
    </div>
  </header>
</template>
