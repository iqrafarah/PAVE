<script setup lang="ts">
// A skill on a vault item, such as "Leiderschap" (Figma: grey, 12px).
defineProps<{
  text: string;
  label?: string;
}>();
</script>

<template>
  <span class="inline-flex h-6 shrink-0 items-center whitespace-nowrap rounded-md bg-chip px-2 text-xs font-medium text-heading">
    <span :aria-hidden="label ? true : undefined">{{ text }}</span>
    <span v-if="label" class="sr-only">{{ label }}</span>
  </span>
</template>
