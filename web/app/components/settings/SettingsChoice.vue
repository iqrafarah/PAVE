<script setup lang="ts">
// One choice in a group on the personalisation page (Figma 1408:17 and 1408:7): a card with an icon and a name, with
// the soft green and a green line when it is the chosen one. A radio button underneath, so the arrow keys work.
defineProps<{
  name: string;
  value: string;
  label: string;
  meaning?: string;
  isSmall?: boolean;
}>();

const chosen = defineModel<string>({ required: true });
</script>

<template>
  <label
    :class="[
      chosen === value ? 'border-brand bg-tint' : 'border-toolbar-line bg-white hover:bg-surface',
      'min-h-13.5 gap-3 px-4',
    ]"
    class="flex cursor-pointer items-center rounded-pill border py-2.5 transition-colors has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand"
  >
    <input v-model="chosen" type="radio" :name="name" :value="value" class="sr-only" />
    <span class="flex shrink-0 items-center justify-center text-heading" aria-hidden="true"><slot /></span>
    <span class="flex min-w-0 flex-col gap-0.5">
      <span class="text-base font-semibold text-heading">{{ label }}</span>
      <span v-if="meaning" class="text-xs font-medium text-subtle">{{ meaning }}</span>
    </span>
  </label>
</template>
