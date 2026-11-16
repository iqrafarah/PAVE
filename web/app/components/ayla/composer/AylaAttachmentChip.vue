<script setup lang="ts">
defineProps<{
  name: string;
  isRemovable?: boolean;
}>();

const emit = defineEmits<{
  remove: [];
}>();
</script>

<template>
  <span
    class="inline-flex max-w-full items-center gap-1.5 rounded-lg border border-line bg-white py-1 pl-2 pr-1 text-sm text-ink"
  >
    <LayoutIcon name="file" />
    <span class="truncate">{{ name }}</span>
    <button
      v-if="isRemovable"
      type="button"
      class="rounded-md p-1 text-muted hover:bg-surface hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('remove')"
    >
      <LayoutIcon name="close" />
      <span class="sr-only">{{ AYLA_REMOVE_FILE }}: {{ name }}</span>
    </button>
  </span>
</template>
