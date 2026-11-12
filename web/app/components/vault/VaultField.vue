<script setup lang="ts">
// A label with its green asterisk above a field (Figma "Titel *"), and what is missing under it.
defineProps<{
  label: string;
  for?: string;
  problem?: string;
  problemId?: string;
  isGroup?: boolean;
}>();
</script>

<template>
  <div class="flex min-w-0 flex-col">
    <component
      :is="isGroup ? 'span' : 'label'"
      :for="isGroup ? undefined : $props.for"
      :id="isGroup ? `${$props.for}-label` : undefined"
      class="mb-3 text-sm font-semibold text-heading"
    >
      {{ label }}
      <span class="text-brand" aria-hidden="true">*</span>
      <span class="sr-only">({{ VAULT_REQUIRED }})</span>
    </component>
    <slot />
    <p v-if="problem" :id="problemId" class="mt-1.5 text-xs text-danger">{{ problem }}</p>
  </div>
</template>
