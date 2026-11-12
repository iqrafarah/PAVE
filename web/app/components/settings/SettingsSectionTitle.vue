<script setup lang="ts">
// iOS SettingsScreen: a muted header above a group of cards (bodyMedium, inkMuted, 8 in from the left).
defineProps<{
  id: string;
  title: string;
}>();
</script>

<template>
  <h2 :id="id" class="pl-2 text-sm font-medium text-subtle">{{ title }}</h2>
</template>
