<script setup lang="ts">
// iOS AylaUndoBar: shown for a few seconds after deleting chats or forgetting a note. What happened, and a way back.
defineProps<{
  message: string;
}>();

const emit = defineEmits<{
  undo: [];
}>();
</script>

<template>
  <div
    role="status"
    class="fixed inset-x-4 bottom-4 z-50 mx-auto flex min-h-13 max-w-md items-center gap-3 rounded-full bg-white/90 pl-4.5 pr-3 shadow-lg backdrop-blur"
  >
    <LayoutPaveIcon name="trash" class="size-4.5 text-subtle" />
    <span class="min-w-0 flex-1 text-sm font-medium text-heading">{{ message }}</span>
    <button
      type="button"
      class="min-h-11 rounded-lg px-2 text-sm font-medium text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('undo')"
    >
      {{ AYLA_UNDO }}
    </button>
  </div>
</template>
