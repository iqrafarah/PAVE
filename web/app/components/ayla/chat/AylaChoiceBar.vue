<script setup lang="ts">
import type { AylaChoice } from '~/types/ayla';

const props = defineProps<{
  question: string;
  choices: AylaChoice[];
  // A question about the vault shows the folder with "Kluis" above the choices (Figma 976:7971).
  isAboutVault?: boolean;
  // A line of the app above the choices, such as "Graduaat in het programmeren staat in je kluis." (with a tick).
  caption?: string;
}>();

const emit = defineEmits<{
  choose: [label: string];
}>();

// From this many characters a choice no longer reads well in a third of the tray: every choice gets its own row.
const LONG_CHOICE = 26;
const isStacked = computed(() => props.choices.some((choice) => choice.label.trim().length > LONG_CHOICE));
</script>

<template>
  <AylaTray>
    <template v-if="caption" #strip>
      <span class="flex items-start gap-1.75 py-1 text-xs font-semibold text-heading">
        <span class="mt-px flex size-4 shrink-0 items-center justify-center rounded-full bg-brand text-white" aria-hidden="true">
          <LayoutPaveIcon name="check" class="size-2.5" />
        </span>
        {{ caption }}
      </span>
    </template>
    <template v-else-if="isAboutVault" #strip>
      <span class="flex items-center gap-1.75 font-heading text-xs font-semibold text-heading">
        <VaultIcon src="/images/ayla/pill-vault.svg" :width="20.3122" :height="18" class="text-brand" />
        {{ AYLA_VAULT_LABEL }}
      </span>
    </template>
    <!-- Short choices share a row at the same width and wrap when the tray is too narrow; a long one gets a row of its own. -->
    <div role="group" :aria-label="question" class="flex flex-wrap gap-1.25">
      <button
        v-for="choice in choices"
        :key="choice.id"
        type="button"
        :class="isStacked ? 'basis-full' : 'flex-[1_1_8rem]'"
        class="min-h-13.25 min-w-0 max-w-full text-balance break-words rounded-composer bg-white px-4 py-2 text-sm/tight font-semibold text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('choose', choice.label)"
      >
        {{ choice.label }}
      </button>
    </div>
  </AylaTray>
</template>
