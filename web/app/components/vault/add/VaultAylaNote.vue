<script setup lang="ts">
// A short line with Ayla's pixel A under something she filled in or chose (iOS VaultAylaNote): "Door Ayla · pagina 1".
defineProps<{
  text: string;
}>();
</script>

<template>
  <p class="mt-1.5 flex items-start gap-1.5 text-[0.6875rem] font-medium text-brand">
    <AylaSlashIcon class="mt-0.5 h-2.5 w-1.5 shrink-0 text-brand!" />
    <span>{{ text }}</span>
  </p>
</template>
