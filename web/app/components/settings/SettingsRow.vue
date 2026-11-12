<script setup lang="ts">
defineProps<{
  to: string;
  title: string;
  icon: string;
  value?: string;
}>();
</script>

<template>
  <NuxtLink :to="to" class="flex min-h-14 items-center gap-3.5 px-3.5 py-2 hover:bg-tint focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand">
    <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-brand text-white">
      <VaultIcon :src="icon" class="size-4.25" />
    </span>
    <span class="min-w-0 flex-1 text-base font-semibold text-heading">{{ title }}</span>
    <span v-if="value" class="max-w-32 truncate text-sm font-medium text-subtle">{{ value }}</span>
    <LayoutPaveIcon name="chevronRight" class="size-3.5 text-subtle" />
  </NuxtLink>
</template>
