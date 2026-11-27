<script setup lang="ts">
// The title above a group in Meldingen that can be folded away (iOS NotificationSectionHeader): click it to hide or
// show its rows. Folded, it says how many wait inside.
const props = defineProps<{
  title: string;
  count: number;
  controls: string;
}>();

const isCollapsed = defineModel<boolean>('collapsed', { required: true });
const label = computed(() => (isCollapsed.value ? SECTION_COLLAPSED(props.title, props.count) : props.title));
</script>

<template>
  <h3>
    <button
      type="button"
      :aria-expanded="!isCollapsed"
      :aria-controls="controls"
      class="flex min-h-8 w-full items-center justify-between gap-2 rounded-lg px-3 text-left text-xs font-medium text-brand hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
      @click="isCollapsed = !isCollapsed"
    >
      {{ label }}
      <LayoutPaveIcon name="chevronRight" :class="isCollapsed ? '' : 'rotate-90'" class="size-3 transition-transform motion-reduce:transition-none" />
    </button>
  </h3>
</template>
