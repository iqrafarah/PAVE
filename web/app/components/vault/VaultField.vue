<script setup lang="ts">
// A label with its green asterisk above a field (Figma "Titel *"), and what is missing under it.
defineProps<{
  label: string;
  for?: string;
  problem?: string;
  problemId?: string;
  isGroup?: boolean;
  // Folders are optional; every other field of the form is required, as in the design.
  isOptional?: boolean;
}>();
</script>

<template>
  <div class="flex min-w-0 flex-col">
    <!-- The label has a fixed height, so a choice beside it (Van – tot / Eén datum) never pushes the field down. -->
    <div class="mb-3 flex h-5 items-center justify-between gap-2">
      <component
        :is="isGroup ? 'span' : 'label'"
        :for="isGroup ? undefined : $props.for"
        :id="isGroup ? `${$props.for}-label` : undefined"
        class="truncate text-sm font-semibold text-heading"
      >
        {{ label }}
        <template v-if="!isOptional">
          <span class="text-brand" aria-hidden="true">*</span>
          <span class="sr-only">({{ VAULT_REQUIRED }})</span>
        </template>
      </component>
      <slot name="aside" />
    </div>
    <slot />
    <p v-if="problem" :id="problemId" class="mt-1.5 text-xs text-danger">{{ problem }}</p>
  </div>
</template>
