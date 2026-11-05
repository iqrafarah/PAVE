<script setup lang="ts">
defineProps<{
  number: number;
  title: string;
  description: string;
}>();
</script>

<template>
  <li class="flex gap-3">
    <span
      class="flex size-6 shrink-0 items-center justify-center rounded-full bg-tint text-xs font-semibold text-brand"
      aria-hidden="true"
    >
      {{ number }}
    </span>
    <div class="flex-1">
      <p class="text-sm font-semibold text-ink">
        <span class="sr-only">Stap {{ number }}: </span>{{ title }}
      </p>
      <p class="mt-0.5 text-sm text-muted">{{ description }}</p>
      <slot />
    </div>
  </li>
</template>
