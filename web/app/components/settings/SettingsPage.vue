<script setup lang="ts">
defineProps<{ title: string }>();
</script>

<template>
  <div class="min-h-0 flex-1 overflow-y-auto bg-surface">
    <SettingsPageHeader :title="title" :back-to="SETTINGS_PATH" :back-label="SETTINGS_TITLE" />
    <div class="mx-auto flex w-full max-w-140 flex-col gap-3 px-5.75 pb-8 pt-4">
      <slot />
    </div>
  </div>
</template>
