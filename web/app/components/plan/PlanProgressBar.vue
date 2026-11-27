<script setup lang="ts">
// How far a plan is, from 0 to 1 (iOS PlanProgressBar).
const props = defineProps<{
  progress: number;
  label: string;
}>();

const percent = computed(() => Math.round(Math.min(Math.max(props.progress, 0), 1) * 100));
</script>

<template>
  <div role="progressbar" :aria-valuenow="percent" aria-valuemin="0" aria-valuemax="100" :aria-valuetext="label" class="h-1.5 w-full overflow-hidden rounded-full bg-tint">
    <div class="h-full rounded-full bg-brand transition-[width] duration-300 motion-reduce:transition-none" :style="{ width: `${percent}%` }" />
  </div>
</template>
