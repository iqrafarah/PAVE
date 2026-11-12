<script setup lang="ts">
import type { AylaChoice } from '~/types/ayla';

defineProps<{
  question: string;
  choices: AylaChoice[];
  // A question about the vault shows the folder with "Kluis" above the choices (Figma 976:7971).
  isAboutVault?: boolean;
}>();

const emit = defineEmits<{
  choose: [label: string];
}>();
</script>

<template>
  <AylaTray>
    <template v-if="isAboutVault" #strip>
      <span class="flex items-center gap-1.75 font-heading text-xs font-semibold text-heading">
        <VaultIcon src="/images/ayla/pill-vault.svg" :width="20.3122" :height="18" class="text-brand" />
        {{ AYLA_VAULT_LABEL }}
      </span>
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
