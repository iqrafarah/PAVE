<script setup lang="ts">
// The four steps above "Kluis aanvullen" (Figma): a green circle with a white number for every step you reached, a
// grey ring for the ones still to come, and a line that turns green as you go.
const props = defineProps<{
  current: number;
}>();

// The line runs from the middle of the first circle (15px in) to the middle of the last one.
const progressWidth = computed(() => `calc((100% - 1.875rem) * ${props.current / (VAULT_ADD_STEPS.length - 1)})`);
</script>

<template>
  <ol class="relative flex justify-between px-px" :aria-label="VAULT_ADD_TITLE">
    <span class="absolute inset-x-3.75 top-3.75 h-px bg-step-todo" aria-hidden="true" />
    <span
      class="absolute left-3.75 top-3.75 h-px bg-brand transition-[width] duration-300 motion-reduce:transition-none"
      :style="{ width: progressWidth }"
      aria-hidden="true"
    />
    <li
      v-for="(label, index) in VAULT_ADD_STEPS"
      :key="label"
      :class="index === 0 ? 'items-start' : index === VAULT_ADD_STEPS.length - 1 ? 'items-end' : 'items-center'"
      class="relative flex w-7.5 flex-col"
      :aria-current="index === current ? 'step' : undefined"
    >
      <span
        :class="index <= current ? 'border-brand bg-brand text-white' : 'border-step-todo bg-white text-step-todo'"
        class="flex size-7.5 items-center justify-center rounded-full border-2 font-step text-xs font-semibold"
        aria-hidden="true"
      >
        {{ index + 1 }}
      </span>
      <span
        :class="index <= current ? 'text-brand' : 'text-step-todo'"
        class="mt-1.5 whitespace-nowrap font-step text-[0.6875rem] font-semibold"
      >
        {{ label }}
      </span>
    </li>
  </ol>
</template>
