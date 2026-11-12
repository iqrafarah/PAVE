<script setup lang="ts">
import type { PaveIconName } from '~/utils/paveIcons';

// An icon from the iPhone app, in the current text color (like SwiftUI's renderingMode(.template)).
const props = defineProps<{
  name: PaveIconName;
}>();

const icon = computed(() => PAVE_ICONS[props.name]);
</script>

<template>
  <svg :viewBox="icon.viewBox" class="shrink-0" aria-hidden="true">
    <path
      v-for="(path, index) in icon.paths"
      :key="index"
      :d="path.d"
      :fill="path.stroke ? 'none' : 'currentColor'"
      :fill-rule="path.evenOdd ? 'evenodd' : undefined"
      :clip-rule="path.evenOdd ? 'evenodd' : undefined"
      :stroke="path.stroke ? 'currentColor' : undefined"
      :stroke-width="path.stroke"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
  </svg>
</template>
