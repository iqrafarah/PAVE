<script setup lang="ts">
// Ayla's pixel slash: squares on a diagonal, each one half a square to the right and one square up.
// The size comes from the parent class (Figma: 5 blocks of 6px in headings, 4 blocks of 3.25px to 4.25px in chat).
const props = withDefaults(
  defineProps<{
    blocks?: 4 | 5;
    // How visible each square is, from the bottom one up (for the typing title); all fully visible when left out.
    opacities?: number[];
  }>(),
  { blocks: 5 },
);

const viewBox = computed(() => `0 0 ${props.blocks + 1} ${props.blocks * 2}`);
const squares = computed(() =>
  Array.from({ length: props.blocks }, (_, index) => ({ x: index, y: (props.blocks - 1 - index) * 2 })),
);
</script>

<template>
  <svg class="shrink-0 text-brand" :viewBox="viewBox" fill="currentColor" aria-hidden="true">
    <rect
      v-for="square in squares"
      :key="square.x"
      :x="square.x"
      :y="square.y"
      width="2"
      height="2"
      :opacity="opacities?.[square.x] ?? 1"
    />
  </svg>
</template>
