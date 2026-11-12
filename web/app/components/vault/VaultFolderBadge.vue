<script setup lang="ts">
// A folder in its colour with its icon on it, small (lists) or large (the header of an open folder).
withDefaults(
  defineProps<{
    icon: string;
    color: string;
    size?: 'small' | 'large';
  }>(),
  { size: 'small' },
);
</script>

<template>
  <span :class="size === 'large' ? 'h-11 w-13.5' : 'h-7.5 w-9'" class="relative shrink-0" aria-hidden="true">
    <VaultIcon src="/images/vault/folder-shape.svg" class="size-full" :style="{ color }" />
    <VaultIcon
      :src="icon"
      :class="size === 'large' ? 'size-5' : 'size-3.5'"
      class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-[38%] text-white"
    />
  </span>
</template>
