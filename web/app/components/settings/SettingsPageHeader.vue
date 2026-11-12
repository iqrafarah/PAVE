<script setup lang="ts">
defineProps<{
  title: string;
  wide?: boolean;
  backTo?: string;
  backLabel?: string;
}>();
</script>

<template>
  <header class="sticky top-0 z-10 bg-surface/95 backdrop-blur">
    <div :class="wide ? 'max-w-168' : 'max-w-140'" class="mx-auto grid min-h-16 w-full grid-cols-[1fr_auto_1fr] items-center gap-2 px-4 py-2">
      <NuxtLink
        v-if="backTo"
        :to="backTo"
        :aria-label="backLabel"
        class="flex min-h-11 min-w-11 items-center gap-1 justify-self-start rounded-lg px-1 text-sm font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
      >
        <LayoutPaveIcon name="chevronRight" class="size-5 rotate-180" />
        <span class="hidden sm:inline">{{ backLabel }}</span>
      </NuxtLink>
      <div v-else class="min-w-11 justify-self-start"><LayoutMenuLogo /></div>
      <h1 v-if="backTo" class="text-center text-base font-semibold text-heading">{{ title }}</h1>
      <div v-else class="flex items-center justify-center gap-2">
        <AylaSlashIcon class="h-7.5 w-4.5" />
        <h1 class="text-2xl font-semibold text-brand sm:text-3xl">{{ title }}</h1>
      </div>
      <span aria-hidden="true" class="min-w-11" />
    </div>
  </header>
</template>
