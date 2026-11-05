<script setup lang="ts">
defineProps<{
  eyebrow: string;
  title: string;
  description: string;
}>();
</script>

<template>
  <section class="rounded-2xl border border-line bg-white p-10">
    <div
      v-if="$slots.icon"
      class="mb-5 flex size-11 items-center justify-center rounded-full border border-line bg-surface text-ink"
    >
      <slot name="icon" />
    </div>
    <p class="text-sm font-medium text-brand">{{ eyebrow }}</p>
    <h1 class="mt-3 text-3xl font-semibold text-ink">{{ title }}</h1>
    <p class="mt-3 text-base text-muted">{{ description }}</p>
    <slot />
  </section>
</template>
