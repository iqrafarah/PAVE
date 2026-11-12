<script setup lang="ts">
// Figma exports the Profiel tile with its own background (41 x 38); the others are 24 x 24 icons on a tile.
defineProps<{
  src: string;
  hasOwnTile: boolean;
}>();
</script>

<template>
  <img v-if="hasOwnTile" :src="src" alt="" width="41" height="38" />
  <img v-else :src="src" alt="" width="24" height="24" />
</template>
