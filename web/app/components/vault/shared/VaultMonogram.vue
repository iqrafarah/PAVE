<script setup lang="ts">
// A round white badge with the first letter of the organisation, used when there is no logo (iOS CompanyMonogram).
const props = defineProps<{
  name: string;
  size: number;
}>();

const letter = computed(() => props.name.trim().charAt(0).toLocaleUpperCase('nl') || '?');
</script>

<template>
  <span
    class="flex shrink-0 items-center justify-center rounded-full border border-card-border bg-white font-bold text-brand"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${(size * 26) / 64}px` }"
    aria-hidden="true"
  >
    {{ letter }}
  </span>
</template>
