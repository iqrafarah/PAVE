<script setup lang="ts">
// While Ayla reads (iOS VaultAylaFillSkeleton): the shape of the form she is about to fill in, with a soft pulse, so the
// step after it lands in the same place.
</script>

<template>
  <div class="mt-1.5 flex flex-col gap-4.5" role="status" aria-live="polite">
    <div class="flex items-center gap-3">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-brand motion-safe:animate-pulse" aria-hidden="true">
        <AylaSlashIcon class="h-4.5 w-3 text-white!" />
      </span>
      <p class="text-sm font-semibold text-heading">{{ VAULT_AYLA_FILL_READING }}</p>
    </div>
    <div class="flex flex-col gap-4.5 motion-safe:animate-pulse" aria-hidden="true">
      <div class="grid grid-cols-2 gap-4">
        <div v-for="width in ['w-11', 'w-24']" :key="width" class="flex flex-col gap-2">
          <span :class="width" class="h-3.5 rounded bg-tile" />
          <span class="h-11 rounded-md bg-tile" />
        </div>
      </div>
      <div class="grid grid-cols-2 gap-4">
        <div v-for="width in ['w-32', 'w-15']" :key="width" class="flex flex-col gap-2">
          <span :class="width" class="h-3.5 rounded bg-tile" />
          <span class="h-11 rounded-md bg-tile" />
        </div>
      </div>
      <div class="flex flex-col gap-2">
        <span class="h-3.5 w-22 rounded bg-tile" />
        <span class="h-28.5 rounded-md bg-tile" />
      </div>
    </div>
  </div>
</template>
