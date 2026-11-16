<script setup lang="ts">
useHead({ title: `${SETTINGS_AYLA} - PAVE` });
const memory = useAylaMemory();
const voiceText = useAylaVoiceText();
const showsVoiceText = computed({
  get: () => voiceText.showsVoiceText.value,
  set: (value: boolean) => voiceText.set(value),
});
const memorySummary = computed(() => getMemorySummary(memory.state.value.status, memory.state.value.isEnabled, memory.state.value.notes.length));
onMounted(() => {
  voiceText.load();
  if (memory.state.value.status === 'idle') memory.load();
});
</script>

<template>
  <SettingsPage :title="SETTINGS_AYLA">
    <SettingsLinkCard :to="MEMORY_PAGE_PATH" :title="SETTINGS_MEMORY_LINK" :message="memorySummary" />
    <SettingsSwitchCard v-model="showsVoiceText" :title="SETTINGS_VOICE_TEXT" :explanation="SETTINGS_VOICE_TEXT_EXPLANATION" />
  </SettingsPage>
</template>
