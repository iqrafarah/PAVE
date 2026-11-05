<script setup lang="ts">
defineProps<{
  title: string;
}>();
</script>

<template>
  <div class="mt-6 flex gap-3 rounded-xl bg-tint p-4 text-sm text-ink">
    <svg
      class="size-5 shrink-0"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      aria-hidden="true"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z"
      />
    </svg>
    <div>
      <p class="font-semibold text-brand">{{ title }}</p>
      <p class="mt-1"><slot /></p>
    </div>
  </div>
</template>
