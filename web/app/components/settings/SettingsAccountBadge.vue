<script setup lang="ts">
// iOS AccountBadge: a 44pt circle in the soft green with the first letter of the name, or a person when there is none.
// The web also shows the profile photo when there is one.
const props = defineProps<{
  name: string | null;
  avatarUrl?: string | null;
}>();

const initial = computed(() => props.name?.trim().charAt(0).toUpperCase() ?? '');
</script>

<template>
  <img v-if="avatarUrl" :src="avatarUrl" alt="" class="size-11 shrink-0 rounded-full object-cover" />
  <span
    v-else
    class="flex size-11 shrink-0 items-center justify-center rounded-full bg-tint font-heading text-base font-semibold text-brand"
    aria-hidden="true"
  >
    <template v-if="initial">{{ initial }}</template>
    <LayoutPaveIcon v-else name="person" class="h-4.25 w-3.5" />
  </span>
</template>
