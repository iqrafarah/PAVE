<script setup lang="ts">
// Ayla's status blocks, moving exactly as on iOS (AylaStatusIndicator.swift):
// 'thinking' builds four slashes one by one in a 7-second loop; 'failed' tumbles over once in dark red;
// 'empty' tumbles over once in brand green (Figma "Geen resultaat": nothing was found).
const props = defineProps<{
  label: string;
  mode: 'thinking' | 'failed' | 'empty';
  // Only the big "Gegevens ophalen" loader glows, so its blocks stand out on the placeholder cards.
  glows?: boolean;
}>();

const easeFall = cubicBezier(0.5, 0, 0.5, 1);
const isThinking = computed(() => props.mode === 'thinking');
const clock = useAnimationClock({
  isRunning: () => isThinking.value || clock.seconds.value < FALL_SECONDS,
});

const thinkingProgress = computed(() => {
  if (clock.prefersReducedMotion.value) return THINKING_STILL_PROGRESS;
  return (clock.seconds.value % THINKING_LOOP_SECONDS) / THINKING_LOOP_SECONDS;
});
const fallAmount = computed(() => {
  if (clock.prefersReducedMotion.value) return 1;
  return easeFall(clamp01(clock.seconds.value / FALL_SECONDS));
});
const colorClass = computed(() => (props.mode === 'failed' ? 'text-critical' : 'text-brand'));

watch(() => props.mode, () => clock.start());
onMounted(() => clock.start());
</script>

<template>
  <div class="relative flex flex-col items-center" :role="mode === 'failed' ? 'alert' : 'status'">
    <span v-if="isThinking && glows" class="absolute -inset-x-16 -inset-y-12 rounded-full bg-white blur-3xl" aria-hidden="true" />
    <svg
      v-if="isThinking"
      :class="colorClass"
      class="relative overflow-visible"
      :width="THINKING_FRAME.width"
      :height="THINKING_FRAME.height"
      :viewBox="`0 0 ${THINKING_FRAME.width} ${THINKING_FRAME.height}`"
      fill="currentColor"
      aria-hidden="true"
    >
      <rect
        v-for="(block, index) in THINKING_BLOCKS"
        :key="index"
        :x="block.x"
        :y="block.y"
        :width="THINKING_BLOCK_SIZE"
        :height="THINKING_BLOCK_SIZE"
        :opacity="getThinkingOpacity(index, thinkingProgress)"
      />
    </svg>
    <svg
      v-else
      :class="colorClass"
      class="relative overflow-visible"
      :width="FALLEN_FRAME.width"
      :height="FALLEN_FRAME.height"
      :viewBox="`0 0 ${FALLEN_FRAME.width} ${FALLEN_FRAME.height}`"
      fill="currentColor"
      aria-hidden="true"
    >
      <rect
        v-for="(block, index) in FALLING_BLOCKS"
        :key="index"
        :width="FALLEN_BLOCK_SIZE"
        :height="FALLEN_BLOCK_SIZE"
        :transform="getFallTransform(block, fallAmount)"
      />
    </svg>
    <p :class="colorClass" class="relative mt-3 max-w-80 text-center text-sm font-bold">{{ label }}</p>
  </div>
</template>
