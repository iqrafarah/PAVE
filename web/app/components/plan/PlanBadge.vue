<script setup lang="ts">
// The icon of a plan, from the template it started with (iOS PlanBadge).
withDefaults(
  defineProps<{
    templateId: string | null;
    size?: 'small' | 'large';
  }>(),
  { size: 'small' },
);
</script>

<template>
  <span
    :class="size === 'large' ? 'size-12 rounded-2xl' : 'size-10 rounded-xl'"
    class="flex shrink-0 items-center justify-center bg-tint text-brand"
    aria-hidden="true"
  >
    <VaultIcon :src="planTemplateIcon(templateId)" :class="size === 'large' ? 'size-6' : 'size-5'" />
  </span>
</template>
