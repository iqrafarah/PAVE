<script setup lang="ts">
withDefaults(
  defineProps<{
    type?: 'submit' | 'button';
    disabled?: boolean;
  }>(),
  { type: 'button', disabled: false },
);
</script>

<template>
  <button
    :type="type"
    :disabled="disabled"
    class="mt-6 h-13 w-full rounded-lg bg-brand text-base font-semibold text-white hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
  >
    <slot />
  </button>
</template>
