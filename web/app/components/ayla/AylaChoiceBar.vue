<script setup lang="ts">
import type { AylaChoice } from '~/types/ayla';

defineProps<{
  question: string;
  choices: AylaChoice[];
}>();

const emit = defineEmits<{
  choose: [label: string];
  typeInstead: [];
}>();
</script>

<template>
  <AylaTray>
    <template #strip>
      <button
        type="button"
        class="text-xs font-semibold text-heading underline hover:text-brand focus-visible:outline-2 focus-visible:outline-brand"
        @click="emit('typeInstead')"
      >
        {{ AYLA_TYPE_SOMETHING_ELSE }}
      </button>
    </template>
    <!-- Long or many choices go onto a second line instead of running out of their button. -->
    <div role="group" :aria-label="question" class="flex flex-wrap gap-1.25">
      <button
        v-for="choice in choices"
        :key="choice.id"
        type="button"
        class="min-h-13.25 min-w-28 flex-1 break-words rounded-composer bg-white px-3 py-2 text-sm/tight font-semibold text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('choose', choice.label)"
      >
        {{ choice.label }}
      </button>
    </div>
  </AylaTray>
</template>
