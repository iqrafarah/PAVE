<script setup lang="ts">
// The light green tray around the chat composer and the choice bar (Figma "Rectangle 35", 608 x 101).
// The strip above the content holds the files added to the question.
</script>

<template>
  <div class="relative w-full max-w-152">
    <VaultIcon src="/images/ayla/tray.svg" stretch class="absolute inset-x-0 top-0 h-full w-full text-tint" />
    <div class="relative flex min-h-9.75 flex-wrap items-center gap-2 px-14 pt-2">
      <slot name="strip" />
    </div>
    <div class="relative px-2 pb-2">
      <slot />
    </div>
  </div>
</template>
