<script setup lang="ts">
defineProps<{
  eyebrow?: string;
  title: string;
  description: string;
}>();
</script>

<template>
  <section class="rounded-2xl border border-line bg-white p-6 sm:p-8">
    <slot name="steps" />
    <p v-if="eyebrow && !$slots.steps" class="mb-2 text-sm font-medium text-brand">
      {{ eyebrow }}
    </p>
    <div class="flex items-center gap-3">
      <div
        v-if="$slots.icon"
        class="flex size-10 shrink-0 items-center justify-center rounded-full border border-line bg-surface text-ink"
      >
        <slot name="icon" />
      </div>
      <h1 class="text-2xl font-semibold text-ink sm:text-3xl">{{ title }}</h1>
    </div>
    <p class="mt-2 text-base text-muted">{{ description }}</p>
    <div class="mt-6">
      <slot />
    </div>
  </section>
</template>
