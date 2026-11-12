<script setup lang="ts">
// An icon in the current text colour (like SwiftUI's renderingMode(.template)): the SVG is used as a mask.
const props = defineProps<{
  src: string;
  stretch?: boolean;
  width?: number;
  height?: number;
}>();

const style = computed(() => {
  const size = props.stretch ? '100% 100%' : 'contain';
  const mask = `url(${props.src}) center / ${size} no-repeat`;
  return {
    mask, WebkitMask: mask,
    width: props.width === undefined ? undefined : `${props.width / 16}rem`,
    height: props.height === undefined ? undefined : `${props.height / 16}rem`,
  };
});
</script>

<template>
  <span class="inline-block shrink-0 bg-current" :style="style" aria-hidden="true" />
</template>
