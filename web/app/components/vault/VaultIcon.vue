<script setup lang="ts">
// An icon in the current text colour (like SwiftUI's renderingMode(.template)): the SVG is used as a mask.
const props = defineProps<{
  src: string;
}>();

const style = computed(() => {
  const mask = `url(${props.src}) center / contain no-repeat`;
  return { mask, WebkitMask: mask };
});
</script>

<template>
  <span class="inline-block shrink-0 bg-current" :style="style" aria-hidden="true" />
</template>
