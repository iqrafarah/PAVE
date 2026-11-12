<script setup lang="ts">
const props = defineProps<{ full?: boolean; decorative?: boolean }>();
const style = computed(() => {
  const path = props.full ? '/images/logo.svg' : '/images/ayla/logo-mark.svg';
  const mask = `url(${path}) center / contain no-repeat`;
  return { mask, WebkitMask: mask };
});
</script>

<template>
  <span :role="decorative ? undefined : 'img'" :aria-label="decorative ? undefined : 'PAVE'" :aria-hidden="decorative || undefined" :style="style" class="inline-block shrink-0 bg-brand" />
</template>
