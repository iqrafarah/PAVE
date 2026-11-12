<script setup lang="ts">
defineProps<{
  message: string;
  actionLabel?: string;
  actionTo?: string;
}>();

const emit = defineEmits<{
  action: [];
}>();
</script>

<template>
  <div
    role="alert"
    class="flex flex-wrap items-center gap-3 rounded-xl border border-line bg-white px-4 py-3 text-sm text-ink"
  >
    <p class="min-w-0 flex-1">{{ message }}</p>
    <NuxtLink
      v-if="actionLabel && actionTo"
      :to="actionTo"
      class="rounded-lg bg-brand px-3 py-2 font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
    >
      {{ actionLabel }}
    </NuxtLink>
    <button
      v-else-if="actionLabel"
      type="button"
      class="rounded-lg bg-brand px-3 py-2 font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('action')"
    >
      {{ actionLabel }}
    </button>
  </div>
</template>
