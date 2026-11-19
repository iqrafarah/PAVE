<script setup lang="ts">
// A file added to a message, as on iOS (AylaAttachmentChip): a paperclip and the name on the light tint, no border. In
// the text field with a cross to take it away; above a sent message smaller, several on a line.
defineProps<{
  name: string;
  isRemovable?: boolean;
  isCompact?: boolean;
}>();

const emit = defineEmits<{
  remove: [];
}>();
</script>

<template>
  <span
    :class="[
      isCompact ? 'h-6.5 max-w-47.5 gap-1 rounded-[0.5625rem] pl-2' : 'h-8 max-w-65 gap-1.5 rounded-xl pl-2.5',
      isRemovable ? '' : isCompact ? 'pr-2.25' : 'pr-3',
    ]"
    class="inline-flex items-center bg-tint"
  >
    <VaultIcon
      src="/images/ayla/add-file.svg"
      :class="isCompact ? 'size-3' : 'size-4'"
      class="shrink-0 text-brand"
    />
    <span :title="name" class="min-w-0 truncate text-xs font-medium text-ink">{{ name }}</span>
    <button
      v-if="isRemovable"
      type="button"
      class="-my-1.5 flex h-11 w-9 shrink-0 items-center justify-center rounded-lg text-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('remove')"
    >
      <VaultIcon src="/images/ayla/plus.svg" class="size-2.25 rotate-45" />
      <span class="sr-only">{{ AYLA_REMOVE_FILE }}: {{ name }}</span>
    </button>
  </span>
</template>
