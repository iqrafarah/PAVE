<script setup lang="ts">
defineProps<{ title: string; wide?: boolean }>();
</script>

<template>
  <div class="min-h-0 flex-1 overflow-y-auto bg-surface">
    <SettingsPageHeader :title="title" :wide="wide" :back-to="SETTINGS_PATH" :back-label="SETTINGS_TITLE" />
    <div :class="wide ? 'max-w-168' : 'max-w-140'" class="mx-auto flex w-full flex-col gap-3 px-5.75 pb-8 pt-4">
      <slot />
    </div>
  </div>
</template>
