<script setup lang="ts">
// The welcome title, typed out with PAVE's slash as the cursor, exactly as on iOS (AylaTypingTitle.swift): the slash
// writes the letters, blinks twice, then hands over square by square to the slash in front of the title.
// The full title is laid out from the start, so nothing moves while it types.
const props = defineProps<{
  text: string;
  // Typing starts when this becomes true (after the name is known, so it types only once).
  isReady: boolean;
}>();

const characters = computed(() => Array.from(props.text));
const duration = computed(() => getTypingDuration(characters.value.length));
const hasStarted = ref(false);
const clock = useAnimationClock({ isRunning: () => clock.seconds.value < duration.value });

const moment = computed(() => {
  const count = characters.value.length;
  if (clock.prefersReducedMotion.value) return getFinishedTyping(count);
  if (!hasStarted.value) return { shownCount: 0, cursor: null, front: [] };
  return getTypingMoment(count, clock.seconds.value);
});
const typedText = computed(() => characters.value.slice(0, moment.value.shownCount).join(''));
const restText = computed(() => characters.value.slice(moment.value.shownCount).join(''));
const frontOpacities = computed(() => (hasStarted.value ? moment.value.front : [0, 0, 0, 0, 0]));

function startTyping() {
  if (hasStarted.value || !props.isReady) return;
  hasStarted.value = true;
  clock.start();
}

watch(() => props.isReady, startTyping);
onMounted(startTyping);
</script>

<template>
  <h2 class="flex items-start justify-center gap-2.5 text-center font-heading text-2xl font-semibold text-heading sm:text-hero">
    <AylaSlashIcon :opacities="frontOpacities" class="mt-0.5 h-7.5 w-4.5" />
    <span class="sr-only">{{ text }}</span>
    <span aria-hidden="true">
      <span>{{ typedText }}</span>
      <span class="relative inline-block w-0 align-top">
        <AylaSlashIcon
          v-if="moment.cursor"
          :opacities="moment.cursor"
          class="absolute left-0.75 top-0.5 h-7.5 w-4.5"
        />
      </span>
      <span class="invisible">{{ restText }}</span>
    </span>
  </h2>
</template>
